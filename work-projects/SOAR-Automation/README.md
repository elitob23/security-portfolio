# SOAR Automation

CrowdStrike Falcon Fusion SOAR workflows I've built to automate detection response: moving detections into triage, notifying analysts, and containing hosts when it's safe to do so.

[← Back to portfolio home](../../README.md)

## Workflows

| Workflow | Summary | Trigger | Status |
|---|---|---|---|
| [Falcon OverWatch Detection: Notification & Remediation](Falcon-OverWatch-Detection) | Triages, notifies on, and contains detections attributed to Falcon OverWatch across EPP, IDP, and OverWatch generic detections | Signal → Detection | ✅ Complete |

## Structure

Each workflow lives in its own folder with a README covering its purpose, trigger and filter, branching logic, actions, and prerequisites.
