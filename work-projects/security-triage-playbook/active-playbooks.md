# Active Playbooks

1. # DETECTION NAME: Access from IP with bad reputation

## WHAT IT MEANS:

A user's credentials were used to authenticate to corporate resources from an IP address flagged by global threat intelligence as having a poor reputation (e.g., hosting facilities, proxy nodes, or known scanning networks).

## SEVERITY LEVEL:
Default: Low to Medium

## FIRST 3 THINGS I CHECK:

1. Target Identity & Endpoint: Which user account and endpoint triggered the alert? Is this a standard user, a domain admin, or a service account? Is this behavior typical for their role?

2. Connection Context: Was the connection inbound or outbound? What process initiated the network connection (e.g., web browser, system process, PowerShell, cmd.exe)? Was it a single packet or an ongoing stream?

3. IP Reputation Lookup: Query the external IP in threat intelligence platforms (e.g., VirusTotal, AbuseIPDB). What is it flagged for (C2 infrastructure, malware delivery, scanning, phishing)? Who is the hosting provider?

## FALSE POSITIVE PATTERNS:

Legitimate, business-critical SaaS platforms or cloud services hosted in regional data centers (e.g., Azure, AWS, GCP hosting facilities) mistakenly flagged by intelligence feeds.

One-time, transient outbound connections from web browsers loading third-party ad networks or CDNs.

## ESCALATION THRESHOLD:

Close as Low Risk / Benign if:

* The connection was initiated by a known, legitimate business application.
* The event is a single, isolated connection with no follow-up anomalous activity.
* The IP is a low-reputation hosting provider but is not currently flagged for active malicious campaigns.

## Escalate Immediately if:

* The process making the connection is highly suspicious (e.g., powershell.exe, cmd.exe, wscript.exe, rundll32.exe).
* The connection is persistent, repetitive, or showing signs of active Command & Control (C2) beaconing.
* The IP is actively flagged as hosting live C2 infrastructure.
* The involved account is a high-privilege administrator or a critical system service account.

## HOW TO CLOSE IT:

* Document the endpoint, user, process, destination IP, and threat intelligence reputation results.
* If confirmed benign, resolve the alert in the EDR console (e.g., Falcon) with a detailed note explaining the false positive context.
* If suspicious, immediately isolate the endpoint, revoke active user sessions, prompt a password reset, and escalate to the Incident Response (IR) team. Always update the alert disposition in the console before closing.

## EXAMPLE SCENARIO:

An alert flagged an outbound connection to an IP address located in a Swiss hosting facility. Investigation revealed that a standard workstation initiated a one-time outbound connection via chrome.exe while a user was browsing a legitimate technical forum. The IP was checked on AbuseIPDB; it was a low-reputation VPN server but showed no active malicious tags. No further alerts or lateral movement indicators were found on the endpoint. The alert was documented and closed as a benign false positive.



2. # DETECTION NAME: Suspicious web-based activity (ML)

## WHAT IT MEANS:

Anomalous web-based activity has been detected from a corporate user account accessing resources via a web browser. The activity is flagged by a machine learning model due to highly unusual sign-in patterns, such as access from an uncharacteristic IP address or region. This aligns with MITRE ATT&CK: Valid Accounts (T1078), indicating potential initial access via compromised credentials.

## SEVERITY LEVEL:
Default: Low to Medium

## FIRST 3 THINGS I CHECK:

1. IP & Geolocation Analysis: Identify the source IP and geographical location. Look for previous successful logins from this IP or ISP in the directory logs (e.g., Microsoft Entra ID).
2. User Baseline Deviation: Compare this sign-in with the user's historical sign-in history. Is the user currently traveling, on vacation, or working remotely?
3. Resource & Session Activity: Review what resources were accessed during the anomalous session (e.g., SharePoint sites, admin portals, bulk file downloads). Are there concurrent detections or changes on the account?

## FALSE POSITIVE PATTERNS:
* The user is legitimately traveling or on vacation and logging in without a corporate VPN.
* The IP address matches a residential ISP block that the user has historically used.
* A single sign-in event occurred with no sensitive resource access or configuration changes.

## ESCALATION THRESHOLD:
Close as Low Risk / Benign if:

* The sign-in can be confirmed as legitimate user travel (e.g., verified via Out-of-Office status or direct user confirmation).
* The IP address is found in multiple prior successful, undisputed sign-ins for that user.

Escalate Immediately if:

* Impossible Travel: Concurrent sign-ins occur from two physically distant locations within an impossible timeframe.
* Critical security changes occurred during the session (e.g., MFA methods modified/added, password resets, or security defaults disabled).
* High-volume data exfiltration is detected (e.g., bulk file downloads from SharePoint or OneDrive).
* The user has no knowledge or recollection of initiating the session.
* The source IP is actively listed on AbuseIPDB with high-frequency, recent abuse reports.

## HOW TO CLOSE IT:
* Document the user account, source IP, geographical location, and ISP details.
* Record whether the session was verified as legitimate user activity.
* If confirmed malicious or highly suspicious, escalate immediately: initiate a forced password reset, revoke all active browser sessions in Entra ID, audit for newly added MFA methods, and document the disposition in the EDR/SIEM console.

## EXAMPLE SCENARIO:

An ML-based alert triggered for anomalous web access originating from an IP address geolocated to Mexico. Investigation of the directory logs showed this user had historically only logged in from Canada. There was no approved travel on record. No sensitive resources were downloaded, but because the location was highly anomalous and unverified, the session was terminated, a password reset was enforced, and the user was contacted to re-verify their identity.


3. # DETECTION NAME: Access from multiple locations concurrently

## WHAT IT MEANS:
A single user account successfully authenticated from two geographically distinct locations within a timeframe that is physically impossible to travel (often referred to as an "impossible travel" alert). This strongly suggests compromised credentials or session hijacking.

## SEVERITY LEVEL:
Default: Low to Medium

## FIRST 3 THINGS I CHECK:
1.Time Delta vs. Distance: Calculate the time elapsed between the two sign-ins and the geographical distance. Is it physically possible to travel between them?
2. VPN & ISP Verification: Analyze the network providers. Is one of the locations a known corporate VPN hub, cloud proxy, or cellular network carrier that might mask geolocation?
3. Session Behavior & Auditing: Check the activity performed by both sessions. Is one session doing normal work while the other is attempting administrative actions, bulk downloads, or lateral movement?

## FALSE POSITIVE PATTERNS:
* The user is connected to a corporate or personal VPN that routes traffic through an out-of-province/country data center, while their local machine or mobile device simultaneously syncs mail from their home IP.
* Dual-homed network configurations or mobile devices roaming across cellular towers near regional borders.

## ESCALATION THRESHOLD:
Close as Low Risk / Benign if:

*One of the IP addresses belongs to a verified corporate VPN gateway or trusted SaaS proxy.
* The user confirms they are actively traveling and using multiple local networks (e.g., hotel Wi-Fi and mobile cellular roaming).

Escalate Immediately if:

* The two locations are physically impossible to reach in the given time delta, and neither IP is associated with trusted corporate infrastructure.
* The foreign session attempts configuration writes, MFA modifications, data downloads, or executes administrative scripts.
* The anomalous session originates from a high-risk country where the organization has no business presence.

## HOW TO CLOSE IT:

* Document the user, both source IPs, geolocations, ISPs, and the calculated time delta.
* Review and pull the full unified audit logs for both active sessions.
* If a true positive is suspected, immediately revoke all active sessions for the user, force an account password reset, audit recently registered MFA methods to ensure no persistence has been established, and escalate. Note the disposition in the console.

## EXAMPLE SCENARIO:

An alert flagged a user account logging in from Mexico and Canada within a 10-minute window. Analysis showed the user was on an approved vacation in Mexico and successfully authenticated to the corporate SSL VPN gateway (which routed their traffic to the Canadian datacenter) while their personal mobile device simultaneously checked emails using the local resort Wi-Fi. Because both IPs were verified as legitimate user actions under travel conditions, the alert was documented and marked as benign.


4. # DETECTION NAME: Anomalous RPC (account discovery)

## WHAT IT MEANS:

An endpoint has initiated an anomalous DCE/RPC (Distributed Computing Environment / Remote Procedure Call) command targeting a Domain Controller to query active directory objects. This behavior is a common precursor to lateral movement, mapping directly to MITRE ATT&CK: Account Discovery (T1087).

## SEVERITY LEVEL:
Default: Low to Medium

## FIRST 3 THINGS I CHECK:
1. Source Asset & Role: Identify the source host initiating the RPC request. Is it a dedicated IT management workstation, an automated server, or a standard employee workstation?
2. Actor Privilege & Credentials: Review the user or service account executing the command. Is it a member of the domain admins, a standard user, or a known service account?
3. Process Lineage: Inspect the specific process making the RPC call. Is it a trusted IT management agent (e.g., RMM, backup agent, system service) or an interactive shell (e.g., cmd.exe, powershell.exe)?

## FALSE POSITIVE PATTERNS:
* Legitimate IT Remote Monitoring and Management (RMM) tools or network scanners querying the domain for inventory purposes.
* Domain Controllers performing routine DC-to-DC replication processes.
* Automated backup solutions, endpoint protection agents (such as the EDR sensor itself), or internal asset discovery scanners.

## ESCALATION THRESHOLD:
Close as Low Risk / Benign if:

* The source host and executing account can be positively attributed to a verified administrative tool, monitoring agent, or scheduled task running at that specific time.
* The RPC calls are routine DC-to-DC replication traffic.

Escalate Immediately if:

* The source host is a standard, non-IT employee workstation.
* The executing account is a standard end-user with no administrative responsibilities.
* The activity occurs outside normal operational hours and is followed by subsequent lateral connection attempts (e.g., SMB/RDP brute forcing).
* A high volume of user accounts, groups, or domain objects are enumerated in an extremely tight timeframe.

## HOW TO CLOSE IT:

* Document the source host, its network role, the executing account, and the target domain controller.
* Identify and record the exact process executable name that initiated the RPC calls.
* Clearly state the justification for ruling out malicious intent (e.g., "Attributed to scheduled weekly backup inventory script run by service account svc-backup"). Update the platform alert state before closing.

## EXAMPLE SCENARIO:

An alert was triggered when a administrative account initiated a DCE/RPC account discovery query targeting domain controller dc-01.corp.local from a secondary server dc-02.corp.local. Analysis of the process logs confirmed the activity was part of a routine, scheduled Active Directory replication job run by the directory service itself. No anomalous binaries or interactive command executions were observed on the originating host. The event was logged and resolved as a benign administrative false positive.
