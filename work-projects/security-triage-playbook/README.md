# Security Triage & Incident Response Playbooks

A collection of practical, ground-up triage playbooks for security analysts. Each one gives an actionable, structured workflow for investigating, escalating, or safely closing a common security detection.

<img width="700" height="500" alt="image" src="https://github.com/user-attachments/assets/cf88292b-89d4-4ba8-bb4f-5815eb5e1b6d" />

## Why these playbooks?

Most security documentation is either too academic or buried in a vendor manual. These focus on practical application:

- **Action oriented** — written for the analyst in the hot seat, with a "First 3 things I check" methodology.
- **Noise reduction** — built-in false positive patterns to identify benign activity quickly.
- **Clear boundaries** — explicit escalation thresholds, so you know exactly when to close a ticket and when to sound the alarm.

## Playbooks

Start at the index: **[active-playbooks.md](active-playbooks.md)**

| # | Playbook | Default severity |
|---|---|---|
| 1 | [Access from IP with Bad Reputation](playbooks/access-from-bad-reputation-ip.md) | Low – Medium |
| 2 | [Suspicious Web-Based Activity (ML)](playbooks/suspicious-web-activity-ml.md) | Low – Medium |
| 3 | [Access from Multiple Locations Concurrently](playbooks/concurrent-location-access.md) | Low – Medium |
| 4 | [Anomalous RPC (Account Discovery)](playbooks/anomalous-rpc-account-discovery.md) | Low – Medium |

## Structure

```text
security-triage-playbook/
├── README.md              # This file — format, conventions, index
├── active-playbooks.md    # Playbook index and shared escalation triggers
└── playbooks/             # One file per detection
    ├── access-from-bad-reputation-ip.md
    ├── suspicious-web-activity-ml.md
    ├── concurrent-location-access.md
    └── anomalous-rpc-account-discovery.md
```

Playbook files are named in lowercase with hyphens, after the detection they cover.

## Playbook master template

Every playbook follows the same predictable format:

```text
# DETECTION NAME
[The unique identifier or alert classification]

Summary table: default severity | MITRE ATT&CK | primary platform | typical disposition

## What it means
[In plain English, what behaviour or event triggered this alert?]

## First 3 things I check
1. [Core telemetry investigation]
2. [Identity & endpoint correlation]
3. [Threat intelligence & reputation validation]

## False positive patterns
[Benign scenarios, expected admin behaviour, or known safe noise]

## Escalation threshold
[When to safely close as benign vs. when to escalate and isolate immediately]

## How to close it
[Resolution steps, documentation requirements, and platform dispositions]

## Example scenario
[A sanitized, real-world scenario illustrating the playbook in action]
```

## Notes

- All playbooks are sanitized. No real hostnames, usernames, IP addresses, or domains appear in them — example scenarios use placeholder values.
- Severity levels shown are typical platform defaults, not final dispositions.
- This is a personal reference repository and is not affiliated with or endorsed by any vendor named in it.
