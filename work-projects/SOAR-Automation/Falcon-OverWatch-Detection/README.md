workflow_documentation:
  name: "Falcon OverWatch Detection Notification and Remediation - All Detection Types"
  version: "~1"  # from trigger version constraint
  last_modified: "2026-08-12"  # as reported by the workflow metadata

  overview:
    purpose: >-
      Automate analyst notification and baseline response actions when a Falcon detection
      is attributed to Falcon OverWatch (MITRE tactic = "Falcon Overwatch").
    threat_mitigated: >-
      Adversary activity identified/triaged by Falcon OverWatch across detection types
      (e.g., EPP, IDP, and OverWatch generic detections).
    expected_operational_outcome:
      - Detection is immediately moved to an active triage state (in_progress)
      - Analysts are notified via email with context
      - Related user and endpoint are added to watchlists for heightened monitoring
      - Where applicable (EPP on workstations), the endpoint is contained to reduce spread
      - The detection is annotated with a workflow comment documenting actions taken

  prerequisites:
    crowdstrike_modules:
      - Falcon Fusion SOAR
      - Falcon OverWatch
      - Falcon Insight XDR (for detections/visibility)
      - Falcon Prevent (EPP)  # required for EPP branch actions like containment
      - Falcon Identity Protection (IDP)  # required if IDP detections are in-scope
    integrations:
      - Email (Fusion email action configured: SMTP/O365/Gmail depending on your tenant)
    permissions_in_falcon:
      - Ability to update detection status and add comments
      - Ability to add users/endpoints to watchlists
      - Ability to contain hosts (at least for workstation endpoints)

  triggers_and_conditions:
    trigger:
      type: "Signal"
      name: "Detection"
      fires_when: "A detection occurs"
    primary_filter:
      field: "mitre_tactic"
      operator: "equals"
      value: "Falcon Overwatch"
    conditional_branching:
      - branch_key: "detection_product"
        branches:
          - name: "EPP"
            additional_conditions:
              - field: "sensor_host_type"
                operator: "equals"
                value: "Workstation"
                effect: "Allows containment path"
          - name: "IDP"
            additional_conditions: []
          - name: "OverWatch Generic Detection"
            additional_conditions: []
    parallelism:
      description: "Multiple actions execute in parallel within each detection-type branch."

  action_steps:
    common_initial_actions:
      - step: 1
        action: "Set detection status"
        value: "in_progress"
      - step: 2
        action: "Send email notification"
        recipients: "Security analysts (configured distribution)"
      - step: 3
        action: "Add user to watchlist"
        source: "User referenced by detection"
      - step: 4
        action: "Add endpoint to watchlist"
        source: "Host referenced by detection"

    epp_branch:
      when: "detection_product == EPP"
      workstation_path:
        when: "sensor_host_type == Workstation"
        actions:
          - step: 5
            action: "Contain device"
            notes: "Only for workstation endpoints per workflow logic"
          - step: 6
            action: "Add comment to detection"
            comment_purpose: "Record containment + notifications/watchlist actions"
      non_workstation_path:
        when: "sensor_host_type != Workstation"
        actions:
          - step: 5
            action: "Add comment to detection"
            comment_purpose: "Record notifications/watchlist actions (no containment)"

    idp_branch:
      when: "detection_product == IDP"
      actions:
        - step: 5
          action: "Add comment to detection"
          comment_purpose: "Record notifications/watchlist actions"

    overwatch_generic_branch:
      when: "detection_product == OverWatch Generic Detection"
      actions:
        - step: 5
          action: "Add comment to detection"
          comment_purpose: "Record notifications/watchlist actions"

  required_api_scopes:
    note: >-
      Exact scopes can vary by action version and tenant configuration.
      Below are the typical Falcon OAuth scopes needed to perform the described actions.
    scopes:
      - "fusion:write"           # manage/execute Fusion workflows (name may vary by tenant)
      - "detections:write"       # set detection status, add detection comments
      - "watchlists:write"       # add users/endpoints to watchlists
      - "hosts:write"            # contain host/device (host containment)
      - "identity-protection:write"  # if IDP entities/actions are invoked in your branch

  validation_checks:
    - "Confirm the email integration used by the workflow is configured and permitted."
    - "Confirm containment is allowed for the relevant workstation groups."
    - "Confirm watchlist targets (user + host) are resolvable from detection context."

