# Suspicious Web-Based Activity (ML)

| | |
|---|---|
| **Default severity** | Low – Medium |
| **MITRE ATT&CK** | [T1078 — Valid Accounts](https://attack.mitre.org/techniques/T1078/) |
| **Primary platform** | Microsoft Entra ID sign-in logs + EDR / SIEM |
| **Typical disposition** | Split — legitimate travel vs. credential compromise |

## What it means

Anomalous web-based activity has been detected from a corporate user account accessing resources via a web browser. A machine learning model flagged the activity because of highly unusual sign-in patterns, such as access from an uncharacteristic IP address or region. This indicates potential initial access using compromised credentials.

## First 3 things I check

**1. IP and geolocation analysis**
Identify the source IP and geographic location. Look for previous successful logins from this IP or ISP in the directory logs.

**2. User baseline deviation**
Compare this sign-in against the user's historical sign-in history. Is the user travelling, on vacation, or working remotely?

**3. Resource and session activity**
Review what was accessed during the anomalous session — SharePoint sites, admin portals, bulk file downloads. Are there concurrent detections or changes on the account?

## False positive patterns

- The user is legitimately travelling or on vacation and logging in without the corporate VPN.
- The IP address falls in a residential ISP block the user has historically used.
- A single sign-in event with no sensitive resource access or configuration changes.

## Escalation threshold

**Close as low risk / benign if:**

- The sign-in can be confirmed as legitimate user travel, verified through an out-of-office status or direct user confirmation.
- The IP address appears in multiple prior successful, undisputed sign-ins for that user.

**Escalate immediately if:**

- **Impossible travel** — concurrent sign-ins from two physically distant locations within an impossible timeframe.
- Critical security changes occurred during the session: MFA methods modified or added, password resets, security defaults disabled.
- High-volume data exfiltration is detected, such as bulk downloads from SharePoint or OneDrive.
- The user has no knowledge or recollection of initiating the session.
- The source IP is listed on AbuseIPDB with high-frequency, recent abuse reports.

## How to close it

1. Document the user account, source IP, geographic location, and ISP details.
2. Record whether the session was verified as legitimate user activity.
3. If confirmed malicious or highly suspicious, escalate immediately: force a password reset, revoke all active browser sessions in Entra ID, audit for newly added MFA methods, and document the disposition in the EDR / SIEM console.

## Example scenario

An ML-based alert triggered for anomalous web access originating from an IP geolocated to Mexico. Directory logs showed this user had historically only signed in from Canada, and there was no approved travel on record. No sensitive resources were downloaded, but because the location was highly anomalous and unverified, the session was terminated, a password reset was enforced, and the user was contacted to re-verify their identity.

---

[← Back to playbook index](../active-playbooks.md)
