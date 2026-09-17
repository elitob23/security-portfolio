# Active Playbooks

The triage playbooks currently in active use. Each one lives in its own file under [`playbooks/`](playbooks/) and follows the [master template](README.md#playbook-master-template).

| # | Playbook | What it catches | Default severity | ATT&CK |
|---|---|---|---|---|
| 1 | [Access from IP with Bad Reputation](playbooks/access-from-bad-reputation-ip.md) | Authentication or network traffic involving an IP flagged by threat intelligence | Low – Medium | [T1071](https://attack.mitre.org/techniques/T1071/) |
| 2 | [Suspicious Web-Based Activity (ML)](playbooks/suspicious-web-activity-ml.md) | ML-flagged anomalous browser sign-ins from unusual IPs or regions | Low – Medium | [T1078](https://attack.mitre.org/techniques/T1078/) |
| 3 | [Access from Multiple Locations Concurrently](playbooks/concurrent-location-access.md) | "Impossible travel" — one account, two locations, no way to travel between them | Low – Medium | [T1078](https://attack.mitre.org/techniques/T1078/) |
| 4 | [Anomalous RPC (Account Discovery)](playbooks/anomalous-rpc-account-discovery.md) | DCE/RPC enumeration of Active Directory objects against a Domain Controller | Low – Medium | [T1087](https://attack.mitre.org/techniques/T1087/) |

## Quick reference

Escalation triggers that appear across multiple playbooks — if any of these are true, stop triaging and escalate:

- A high-privilege or service account is involved.
- MFA methods were added or modified during the session.
- Bulk downloads or data staging occurred.
- An interactive shell (`powershell.exe`, `cmd.exe`, `wscript.exe`, `rundll32.exe`) initiated the activity.
- The activity repeats, beacons, or is followed by lateral connection attempts.

## Coverage notes

- All playbooks are sanitized. Hostnames, usernames, IPs, and domains in example scenarios are placeholders.
- Severities listed are platform defaults, not final dispositions. The escalation threshold in each playbook determines the actual outcome.
