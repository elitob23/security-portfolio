# Anomalous RPC (Account Discovery)

| | |
|---|---|
| **Default severity** | Low – Medium |
| **MITRE ATT&CK** | [T1087 — Account Discovery](https://attack.mitre.org/techniques/T1087/) |
| **Primary platform** | CrowdStrike Falcon (EDR) + Domain Controller telemetry |
| **Typical disposition** | Usually benign IT tooling; a precursor to lateral movement when not |

## What it means

An endpoint has initiated an anomalous DCE/RPC (Distributed Computing Environment / Remote Procedure Call) command targeting a Domain Controller to query Active Directory objects. This behaviour is a common precursor to lateral movement.

## First 3 things I check

**1. Source asset and role**
Identify the host initiating the RPC request. Is it a dedicated IT management workstation, an automated server, or a standard employee workstation?

**2. Actor privilege and credentials**
Review the user or service account executing the command. Is it a domain admin, a standard user, or a known service account?

**3. Process lineage**
Inspect the specific process making the RPC call. Is it a trusted IT management agent (RMM, backup agent, system service) or an interactive shell such as `cmd.exe` or `powershell.exe`?

## False positive patterns

- Legitimate IT Remote Monitoring and Management (RMM) tools or network scanners querying the domain for inventory.
- Domain Controllers performing routine DC-to-DC replication.
- Automated backup solutions, endpoint protection agents (including the EDR sensor itself), or internal asset discovery scanners.

## Escalation threshold

**Close as low risk / benign if:**

- The source host and executing account can be positively attributed to a verified administrative tool, monitoring agent, or scheduled task running at that time.
- The RPC calls are routine DC-to-DC replication traffic.

**Escalate immediately if:**

- The source host is a standard, non-IT employee workstation.
- The executing account is a standard end-user with no administrative responsibilities.
- The activity occurs outside normal operational hours and is followed by lateral connection attempts, such as SMB or RDP brute forcing.
- A high volume of user accounts, groups, or domain objects is enumerated in an extremely tight timeframe.

## How to close it

1. Document the source host, its network role, the executing account, and the target domain controller.
2. Identify and record the exact process executable that initiated the RPC calls.
3. State the justification for ruling out malicious intent — for example, *"Attributed to scheduled weekly backup inventory script run by service account `svc-backup`."*

Update the platform alert state before closing.

## Example scenario

An alert triggered when an administrative account initiated a DCE/RPC account discovery query targeting domain controller `dc-01.corp.local` from a secondary server, `dc-02.corp.local`. Process logs confirmed the activity was part of a routine, scheduled Active Directory replication job run by the directory service itself. No anomalous binaries or interactive command executions were observed on the originating host. The event was logged and resolved as a benign administrative false positive.

---

[← Back to playbook index](../active-playbooks.md)
