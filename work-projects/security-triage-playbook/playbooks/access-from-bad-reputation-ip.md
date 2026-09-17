# Access from IP with Bad Reputation

| | |
|---|---|
| **Default severity** | Low – Medium |
| **MITRE ATT&CK** | [T1071 — Application Layer Protocol](https://attack.mitre.org/techniques/T1071/) |
| **Primary platform** | CrowdStrike Falcon (EDR / NG-SIEM) |
| **Typical disposition** | False positive, with a small number of true C2 findings |

## What it means

A user's credentials were used to authenticate to corporate resources from an IP address flagged by global threat intelligence as having a poor reputation — for example a hosting facility, a proxy node, or a known scanning network.

## First 3 things I check

**1. Target identity and endpoint**
Which user account and endpoint triggered the alert? Is this a standard user, a domain admin, or a service account? Is this behaviour typical for their role?

**2. Connection context**
Was the connection inbound or outbound? What process initiated it — a web browser, a system process, `powershell.exe`, `cmd.exe`? Was it a single packet or an ongoing stream?

**3. IP reputation lookup**
Query the external IP in threat intelligence platforms such as VirusTotal and AbuseIPDB. What is it flagged for — C2 infrastructure, malware delivery, scanning, phishing? Who is the hosting provider?

## False positive patterns

- Legitimate, business-critical SaaS platforms or cloud services hosted in regional data centres (Azure, AWS, GCP) that intelligence feeds have mistakenly flagged.
- One-time, transient outbound connections from web browsers loading third-party ad networks or CDNs.

## Escalation threshold

**Close as low risk / benign if:**

- The connection was initiated by a known, legitimate business application.
- The event is a single, isolated connection with no follow-up anomalous activity.
- The IP belongs to a low-reputation hosting provider but is not currently flagged for an active malicious campaign.

**Escalate immediately if:**

- The process making the connection is suspicious — `powershell.exe`, `cmd.exe`, `wscript.exe`, `rundll32.exe`.
- The connection is persistent, repetitive, or shows signs of active C2 beaconing.
- The IP is actively flagged as hosting live C2 infrastructure.
- The account involved is a high-privilege administrator or a critical service account.

## How to close it

1. Document the endpoint, user, process, destination IP, and threat intelligence reputation results.
2. If confirmed benign, resolve the alert in the EDR console with a detailed note explaining the false positive context.
3. If suspicious, isolate the endpoint, revoke active user sessions, prompt a password reset, and escalate to the IR team.

Always update the alert disposition in the console before closing.

## Example scenario

An alert flagged an outbound connection to an IP address located in a Swiss hosting facility. Investigation revealed that a standard workstation initiated a one-time outbound connection via `chrome.exe` while a user was browsing a legitimate technical forum. The IP was checked on AbuseIPDB: a low-reputation VPN server, but with no active malicious tags. No further alerts or lateral movement indicators were found on the endpoint. The alert was documented and closed as a benign false positive.

---

[← Back to playbook index](../active-playbooks.md)
