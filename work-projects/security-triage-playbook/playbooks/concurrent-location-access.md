# Access from Multiple Locations Concurrently

| | |
|---|---|
| **Default severity** | Low – Medium |
| **MITRE ATT&CK** | [T1078 — Valid Accounts](https://attack.mitre.org/techniques/T1078/) |
| **Primary platform** | Identity provider sign-in logs + unified audit log |
| **Typical disposition** | Often benign (VPN / roaming), but high impact when real |

## What it means

A single user account successfully authenticated from two geographically distinct locations within a timeframe that is physically impossible to travel — commonly called an "impossible travel" alert. This strongly suggests compromised credentials or session hijacking.

## First 3 things I check

**1. Time delta vs. distance**
Calculate the time elapsed between the two sign-ins and the geographic distance between them. Is it physically possible to travel between them?

**2. VPN and ISP verification**
Analyse the network providers. Is one location a known corporate VPN hub, cloud proxy, or cellular carrier that could mask geolocation?

**3. Session behaviour and auditing**
Check the activity performed by both sessions. Is one doing normal work while the other attempts administrative actions, bulk downloads, or lateral movement?

## False positive patterns

- The user is connected to a corporate or personal VPN routing traffic through an out-of-province or out-of-country data centre, while their local machine or mobile device simultaneously syncs mail from their home IP.
- Dual-homed network configurations, or mobile devices roaming across cellular towers near regional borders.

## Escalation threshold

**Close as low risk / benign if:**

- One of the IP addresses belongs to a verified corporate VPN gateway or trusted SaaS proxy.
- The user confirms they are actively travelling and using multiple local networks, such as hotel Wi-Fi plus mobile cellular roaming.

**Escalate immediately if:**

- The two locations are physically impossible to reach in the given time delta, and neither IP is associated with trusted corporate infrastructure.
- The foreign session attempts configuration writes, MFA modifications, data downloads, or administrative scripts.
- The anomalous session originates from a high-risk country where the organization has no business presence.

## How to close it

1. Document the user, both source IPs, geolocations, ISPs, and the calculated time delta.
2. Pull and review the full unified audit logs for both active sessions.
3. If a true positive is suspected, revoke all active sessions for the user, force a password reset, audit recently registered MFA methods to confirm no persistence was established, and escalate.

Note the disposition in the console before closing.

## Example scenario

An alert flagged a user account signing in from Mexico and Canada within a 10-minute window. Analysis showed the user was on approved vacation in Mexico and had authenticated to the corporate SSL VPN gateway, which routed their traffic to the Canadian data centre, while their personal mobile device simultaneously checked email over the local resort Wi-Fi. Both IPs were verified as legitimate user actions under travel conditions, so the alert was documented and marked benign.

---

[← Back to playbook index](../active-playbooks.md)
