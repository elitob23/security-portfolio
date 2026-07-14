# 300+ User Domain-Wide Password Policy Overhaul
<img width="767" height="400" alt="image" src="https://github.com/user-attachments/assets/6d796e3a-e578-4b22-9c38-3939b21a4d96" />

## Situation
Identity and Access Management. Existing password policy (10 characters,
90-day rotation) left the environment exposed to credential-based attacks
across 300+ user accounts.

## Task
Owned the project end to end — policy design, technical rollout, and
communication to end users.

## Action
- Researched OUs/accounts requiring exclusion from the new policy
- Modified Default Domain Policy: 15-character minimum, removed forced
  periodic expiration (aligned to NIST 800-63B guidance)
- Built user-facing guidance on passphrase creation and provided wordlists
- Set rollout date, notified users in advance
- Built a PowerShell script to force password changes domain-wide

## Technical Detail
Built a PowerShell script targeting a scoped OU (`Get-ADUser -SearchBase`,
subtree scope), with layered exclusion logic: a static excluded-OU list
checked via distinguished name matching, a static excluded-user list, and
an optional excluded-group list flattened recursively via
`Get-ADGroupMember` — all merged into a single exclusion set before
filtering the target population.

For each in-scope user, the script checked for a PasswordNeverExpires
conflict (which would have silently blocked the forced change) and cleared
it before setting ChangePasswordAtLogon. Every action was logged to an
in memory object and exported to timestamped CSV username, DN, whether
NeverExpires was cleaned, and change-flag status for audit purposes.

Triggered a delta Entra ID sync (Start-ADSyncSyncCycle) immediately after
execution to eliminate the on-prem/cloud sync gap rather than waiting on
the default schedule.

## Result
Deployed GPO and script with zero execution errors. Ran the rollout at
11pm to avoid business impact. 300+ accounts changed successfully,
20+ excluded as planned. No help desk tickets related to lockouts.

## Skills Demonstrated
PowerShell scripting, Active Directory / Group Policy, Identity and
Access Management, NIST password guidance, change management
