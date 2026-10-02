# privesc-detection

A production correlation rule in Falcon Next-Gen SIEM that detects a likely privilege escalation on a Windows host. It fires when one user logs on remotely, runs a non-elevated shell, and an elevated shell then appears on the same host running as a different user.

Query file: [`privesc-detection.cql`](privesc-detection.cql)

| | |
|---|---|
| **Severity** | Medium |
| **Tactic** | TA0004 Privilege Escalation |
| **Technique** | T1548 Abuse Elevation Control Mechanism |
| **Platform** | Windows |
| **Data source** | `base_sensor`: `UserLogon`, `ProcessRollup2` |
| **Status** | Production |
| **Origin** | Adapted from a CrowdStrike Falcon NG-SIEM correlation rule template, then tuned and deployed |

## Purpose

Most privilege escalation detections look at one event, such as a known exploit tool name or a suspicious command line. Those are easy to evade by renaming a binary or changing arguments.

This rule looks at the **sequence** instead. Once an attacker has a valid credential, the usual steps are:

1. **Get in.** Log on over the network or RDP with the stolen account.
2. **Look around.** Run a shell as that user. It's non-elevated, because the account isn't an admin.
3. **Escalate.** Abuse a misconfigured service, a vulnerable application or a token to get a shell running as a more privileged account.

Any one of those steps alone is normal admin activity. All three on the same host, in order and close together, with a change of user between steps 2 and 3, is much less likely to be harmless.

## Detection logic

The rule tags three kinds of events and only keeps hosts where all three appear.

| Stage | Event | Conditions |
|---|---|---|
| **1. Remote logon** | `UserLogon` | Logon type 3 (network) or 10 (RDP) from a remote IPv4 address |
| **2. Non-elevated shell** | `ProcessRollup2` | Integrity level below High (Low or Medium). Parent is `cmd`, `powershell`, `pwsh`, `powershell_ise` or `explorer`. Image is not in `Program Files` |
| **3. Elevated shell** | `ProcessRollup2` | Integrity level High or System. Image is `cmd`, `powershell`, `pwsh` or `powershell_ise`. Parent is **not** a normal shell launcher (`explorer`, `cmd`, `powershell`, `svchost`, `RuntimeBroker`, `WmiPrvSE`, the Falcon and Defender services). User is not a machine account |

It then groups the events per host into sessions, starting a new session after a 10-minute gap. A session alerts only if:

- the user who logged on is the user who ran the non-elevated shell
- the elevated shell is running as a **different** user
- the events happened in order: logon, then non-elevated shell, then elevated shell
- the session lasted more than one minute

### Why the parent process matters

Stage 3 drops elevated shells started by `explorer`, `cmd` or `powershell`, because that's what an admin approving a UAC prompt or using `runas` looks like. What's left is an elevated shell started by **some other program**, such as a service, a scheduled task binary or a third-party application. That is the pattern you'd expect when a vulnerable or misconfigured program running as SYSTEM or an admin is made to spawn a shell.

Exclusions should therefore be written against `CommandLine`, not the parent. A parent-name exclusion would also hide the next real exploit of that same application.

For a block-by-block walkthrough of the query, see [`howitworks.txt`](howitworks.txt).

## Output

One row per host session that matches.

| Field | Description |
|---|---|
| `aid` | Falcon agent ID of the host |
| `remLogon` | Source and destination of the logon, as `[conn] <remote IP> -> <local IP>` |
| `loggedUser` | Account that logged on |
| `logonTimef` | Logon time |
| `lowPrivUser` / `lowPrivCmdLine` / `lowPrivTimef` | User, command line and time of the non-elevated shell activity |
| `highPrivUser` / `highPrivProcess` / `highPrivCmdLine` / `highPrivTimef` | User, image, command line and time of the elevated shell |
| `highParent` | Program that started the elevated shell. **Start here when you triage** |
| `sessionDuration` / `sessionDurationMin` | How long the matching session lasted |

## Triage

When the rule fires:

1. **Check `highParent`.** Which program launched the elevated shell? A known deployment or management agent points to a false positive. A web server, a database, a print service or an unfamiliar binary needs a closer look.
2. **Check `remLogon`.** Is the source IP a normal admin workstation or jump host for `loggedUser`? A logon from an unusual host, or one the user doesn't normally use, raises the priority.
3. **Read both command lines.** Discovery commands (`whoami /priv`, `net group`, `systeminfo`) in the non-elevated stage, then credential, persistence or account-creation activity in the elevated stage, is a strong true-positive pattern.
4. **Open the process tree** in Falcon for the elevated shell and look at its children.
5. **If it looks real:** network-contain the host, disable or reset `loggedUser`, and treat `highPrivUser` as possibly compromised too.

## Limitations and tuning

- **Correlation is by host and time, not by process tree.** The three stages are matched on `aid` and the 10-minute session window. They aren't linked by logon ID or parent/child process. On a busy multi-user server, unrelated activity can line up by chance. That's the main reason the severity is Medium.
- **Console logons are not covered.** Only logon types 3 and 10 with a remote IPv4 address are matched. Local console logons (type 2) and IPv6-only logons won't start a chain.
- **Only shells count as the elevated stage.** If the attacker's elevated process is `rundll32`, a custom binary or a LOLBin other than `cmd`/`powershell`, stage 3 won't match.
- **Same-user elevation is ignored by design.** A user elevating their own admin account through a UAC bypass doesn't change `UserName`, so it's out of scope for this rule.
- **Fast, scripted escalation can be missed.** The one-minute minimum filters out short bursts of activity, but an automated exploit chain that finishes in under a minute won't alert.
- **Ordering checks use the first event of each stage.** The order tests compare the earliest logon, earliest non-elevated shell and earliest elevated shell in the session, not one specific chain.
- **Multiple users in one session.** `collect()` combines values from every matching event. When several users are active on the host in the same session, the user-equality tests compare those combined values, so a real chain can be missed on terminal servers.
- **Expected false positives.** Approved JIT elevations (see below), and software deployment or management agents that launch PowerShell as SYSTEM while an admin is logged on remotely. Exclude them by command line, using the `CommandLine!=/benign_proc_regex/` lines in the query.

## Results and tuning

The rule started from a CrowdStrike correlation rule template. I tuned it for our environment and put it into production.

**Alerts since go-live:** 3.

**Main false-positive source: Just-in-Time admin elevation.** The rule mostly fires when a user is granted domain admin through our [JIT access system](../../jit-access-model). From the rule's point of view, an approved JIT elevation looks just like an attack: a user logs on, works without elevation, then gets an elevated shell under a privileged account in the same session.

That's expected, and it's a useful check that the rule catches the behavior it's meant to catch. It also means a JIT elevation and a real escalation produce the same alert, so each one has to be checked against the JIT approval record.

**Next tuning step:** suppress alerts that line up with an approved JIT request for the same user and time window, using the approval record from the Falcon Fusion JIT workflow. Then only escalation **without** a matching approval fires. Excluding by account name or parent process would be simpler, but it would also hide a real attacker using those same accounts.

## Status

Production
