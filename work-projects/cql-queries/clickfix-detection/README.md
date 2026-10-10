# clickfix-detection

A scheduled detection in Falcon Next-Gen SIEM for ClickFix attacks on Windows hosts. It flags a shell or LOLBin started directly by a browser, an Office app, a PDF reader or Explorer, and labels each alert with the ClickFix command-line pattern it matches. It comes with five investigation queries that build out the context around an alert.

Detection query: [`clickfix-detection.cql`](clickfix-detection.cql)
Investigation queries: [`investigation/`](investigation)

| | |
|---|---|
| **Severity** | Medium |
| **Tactic** | TA0002 Execution |
| **Technique** | T1204.004 User Execution: Malicious Copy and Paste |
| **Related** | T1059.001 PowerShell, T1218.005 Mshta, T1105 Ingress Tool Transfer |
| **Platform** | Windows |
| **Data source** | `base_sensor`: `ProcessRollup2` (detection). `NetworkConnectIP4`, `DnsRequest`, `NewScriptWritten`, `PeFileWritten`, `DocumentFileWritten` (investigation) |
| **Schedule** | Scheduled search, daily over the last 24 hours |
| **Status** | Production |

## Purpose

ClickFix is a social engineering technique. A compromised or malicious website shows a fake browser check or error message, puts a command on the user's clipboard, and walks the user through pasting it into the Windows Run dialog or a terminal.

The user runs the attacker's command themselves, so there's no exploit, no attachment and no download for email or web filtering to catch. The payload is usually a one-line PowerShell, `mshta` or `certutil` command that pulls down a second stage, often an infostealer or a remote access tool.

What ClickFix can't avoid is the process tree. The command runs as a child of Explorer (the Run dialog) or the browser, and it usually has a recognizable shape: clipboard calls, `iex` / `DownloadString`, base64-encoded commands or hidden windows. This detection looks for that combination.

## Detection logic

The query filters `ProcessRollup2` events in three steps.

| Step | Conditions |
|---|---|
| **1. User-facing parent** | `ParentBaseFileName` is `explorer`, `chrome`, `msedge`, `firefox`, `iexplore`, `WINWORD`, `EXCEL`, `POWERPNT`, `AcroRd32` or `Acrobat` |
| **2. Suspicious child** | `FileName` is `powershell`, `pwsh`, `cmd`, `mshta`, `wscript`, `cscript`, `rundll32` or `certutil` |
| **3. Exclusions** | Drops known legitimate patterns: browser native messaging hosts, OneDrive, signed Windows DLLs run through `rundll32` and hardware vendor utilities |

Between steps 2 and 3, a `case` block sets a `ClickFixPattern` field to the first pattern the command line matches:

| `ClickFixPattern` | What it looks for |
|---|---|
| `Clipboard + execution` | `clip`, `Set-Clipboard` or `Get-Clipboard`, plus `iex`, `iwr`, `irm`, `DownloadString`, `FromBase64String` or `certutil` with a URL |
| `Clipboard + lure wording` | A clipboard call plus words like `verification`, `captcha` or `cloudflare` |
| `Clipboard` | A clipboard call on its own |
| `Encoded command` | `-e` / `-enc` / `-encodedcommand` followed by a base64 blob of 20+ characters |
| `Hidden window + execution` | `-w h` / `-windowstyle hidden` plus `iex` or `DownloadString` |
| `mshta URL` | `mshta` with an `http(s)://` URL |
| `certutil download` | `certutil -urlcache` or `-decode` with a URL |
| `Lure wording + download` | Lure words plus `iwr`, `irm`, `curl`, `wget` or `DownloadString` |
| `None` | None of the above |

`None` results are kept on purpose. A browser or Office app starting a shell is unusual enough to review daily, and a ClickFix variant with new wording would otherwise slip through. The label makes triage faster: sort or filter on it and start with everything that isn't `None`.

For a block-by-block walkthrough of the query, see [`howitworks.txt`](howitworks.txt).

## Output

| Field | Description |
|---|---|
| `@timestamp` | When the process started. Needed for investigation query 2 |
| `ComputerName` | Affected host. Needed for every investigation query |
| `UserName` | Account that ran the process |
| `ParentBaseFileName` | Parent process, for example `chrome.exe` or `explorer.exe` |
| `FileName` | Child process, for example `powershell.exe` |
| `ClickFixPattern` | Which ClickFix pattern matched, or `None`. **Start here when you triage** |
| `CommandLine` | Full command line |
| `ParentProcessId` | Falcon process ID of the parent |
| `TargetProcessId` | Falcon process ID of the flagged process. Needed for investigation queries 1, 3, 4 and 5 |
| `@id` | Event ID, for linking back to the raw event |

## Triage

Sort the results into three buckets using `ClickFixPattern` and `CommandLine`.

| Priority | What it looks like |
|---|---|
| 🚨 **High.** Investigate now | Any `ClickFixPattern` other than `None` |
| ⚠️ **Medium.** Quick check | `None`, but the parent is a browser or Office app, or the command line runs an unfamiliar batch file or script |
| ✅ **Low.** Likely benign | `None`, parent is `explorer.exe` and there are no arguments, only the executable path (for example `"C:\Windows\System32\cmd.exe"`). This is usually a user opening a terminal by hand |

For anything High or Medium, copy `ComputerName`, `TargetProcessId` and `@timestamp` from the alert and move on to the investigation queries.

## Investigation queries

Each query has `REPLACE_WITH_...` placeholders. Fill them in with the values from the alert.

| # | Query | Run | Inputs | What it answers |
|---|---|---|---|---|
| 1 | [`01-child-processes.cql`](investigation/01-child-processes.cql) | ⭐⭐⭐ Always, first | `ComputerName`, `TargetProcessId` | What did the flagged process launch? |
| 2 | [`02-process-timeline.cql`](investigation/02-process-timeline.cql) | ⭐⭐ If 1 is suspicious | `ComputerName`, `@timestamp` | What was the user doing in the 5 minutes before and after? |
| 3 | [`03-network-connections.cql`](investigation/03-network-connections.cql) | ⭐⭐ If 1 is suspicious | `ComputerName`, `TargetProcessId` | Did the process connect out, and to where? |
| 4 | [`04-dns-queries.cql`](investigation/04-dns-queries.cql) | ⭐⭐ If 1 is suspicious | `ComputerName`, `TargetProcessId` | Which domains did the process resolve? |
| 5 | [`05-files-created.cql`](investigation/05-files-created.cql) | ⭐ If 1 is suspicious | `ComputerName`, `TargetProcessId` | Did the process write scripts, executables or documents? |

Queries 3-5 only show activity from the one process ID you give them. In a chain like `cmd → powershell`, the download usually comes from the `powershell` child. Query 1 lists each child's `TargetProcessId`, so run queries 3-5 again with those IDs.

### Reading the results

**1. Child processes**
- ✅ No results: the user opened a shell and didn't run anything. **Benign.**
- ✅ Normal admin commands (`dir`, `cd`, `ipconfig`, `Get-Process`). **Benign.**
- 🚨 `iex`, `DownloadString`, `-enc`, `certutil -urlcache`. **Suspicious.** Run queries 2-5, for the alert's process and for the suspicious child.

**2. Process timeline**
- ⚠️ Browser activity just before the alert: the user may have been on the lure page.
- ⚠️ Several `cmd` or `powershell` launches in quick succession.
- ✅ Normal application use around the alert: likely legitimate.

**3. Network connections**
- ✅ No results, or only known internal servers.
- ⚠️ Unknown external IPs. Look them up.
- 🚨 Known-bad IPs or hosting tied to paste sites. **Malicious.**

**4. DNS queries**
- ✅ No results, or only corporate, Microsoft or Google domains.
- 🚨 Paste sites (`pastebin.com`, `paste.ee`, `hastebin.com`). **Malicious.**
- 🚨 URL shorteners or newly registered domains. **Suspicious.**

**5. Files created**
- ✅ No results.
- ⚠️ Files written to user folders. Look closer.
- 🚨 Scripts (`.ps1`, `.bat`, `.vbs`, `.js`) in temp folders, or downloaded `.exe` / `.dll` files. **Malicious.**

### Verdict

| Evidence | Verdict |
|---|---|
| Malicious child commands + connections to suspicious IPs + DNS lookups for paste sites | 🚨 **Confirmed malicious.** Escalate to incident response |
| Encoded child commands + script or executable written to a temp folder | 🚨 **Confirmed malicious.** Escalate to incident response |
| Normal child commands + no network activity | ✅ **Benign.** Close |
| No child processes + no network activity | ✅ **Benign.** Close, and consider an exclusion if it recurs |

## Example investigations

The values below are illustrative. Hostnames, usernames, IDs and IPs are placeholders.

### Example 1: benign

**Alert**
```
ComputerName:        WORKSTATION-01
UserName:            example.user
ParentBaseFileName:  explorer.exe
FileName:            pwsh.exe
ClickFixPattern:     None
CommandLine:         "C:\Program Files\PowerShell\7\pwsh.exe" -WorkingDirectory ~
TargetProcessId:     <TARGET_PROCESS_ID>
```

**Query 1 (child processes):** no results.

**Verdict:** ✅ **Benign.** The user opened PowerShell from Explorer and didn't run anything. Nothing further to do.

### Example 2: malicious

**Alert**
```
ComputerName:        WORKSTATION-02
UserName:            example.user
ParentBaseFileName:  chrome.exe
FileName:            cmd.exe
ClickFixPattern:     Clipboard + execution
CommandLine:         cmd.exe /c echo <payload> | clip && powershell -enc <BASE64_BLOB>
TargetProcessId:     <CMD_PROCESS_ID>
```

The command line hits two High patterns at once: clipboard manipulation and an encoded PowerShell command. It's labeled with the first one that matches.

**Query 1 (child processes)**
```
FileName:         powershell.exe
CommandLine:      powershell.exe -enc <BASE64_BLOB>
TargetProcessId:  <POWERSHELL_PROCESS_ID>
```
🚨 Encoded PowerShell spawned from the browser's `cmd`. Continue, using `<POWERSHELL_PROCESS_ID>` for queries 3-5.

**Query 3 (network connections)**
```
RemoteAddressIP4:  203.0.113.45
RemotePort:        443
```
🚨 Outbound HTTPS to an unknown external IP.

**Query 4 (DNS queries)**
```
DomainName:  pastebin.com
```
🚨 Resolved a paste site, a common ClickFix second-stage host.

**Verdict:** 🚨 **Confirmed malicious.** Escalate to incident response. Evidence: clipboard manipulation plus encoded PowerShell, an outbound connection to an unknown external IP, and a DNS lookup for a paste site.

## Limitations and tuning

- **Alerts include `None` matches.** Every browser/Office/Explorer → shell or LOLBin pair that survives the exclusions alerts, including someone opening a terminal from Explorer. To alert only on pattern matches, add `| ClickFixPattern!="None"` after the `case` block. The trade-off is that a ClickFix variant using wording or commands not in the patterns is missed.
- **The Run dialog is the main ClickFix path, and it's noisy.** Commands pasted into the Run dialog run as children of `explorer.exe`, which also starts every terminal a user opens by hand. Explorer can't be dropped as a parent without losing the most common ClickFix delivery.
- **Only the first pattern is reported.** `case` stops at the first matching branch, so a command line that hits several patterns shows only one label.
- **Child lists don't cover every LOLBin.** `msiexec`, `regsvr32`, `bitsadmin`, `curl.exe` and `wmic` are also used in ClickFix chains and aren't in the child list. Add them if they show up in threat intel you care about.
- **Command-line evasion.** Pattern matching on `CommandLine` can be beaten with string concatenation, caret escaping, environment variable tricks or by renaming a copied binary. The parent/child pairing still catches these as `None`.
- **Windows only.** macOS ClickFix variants (Terminal pasting `curl | bash`) aren't covered.

### Adding exclusions

When legitimate software shows up repeatedly:

1. Find a stable, specific string in its `CommandLine`, such as an install path or an executable name.
2. Add a line to the `NOT (...)` block in [`clickfix-detection.cql`](clickfix-detection.cql):
   ```
   OR (FileName="cmd.exe" AND CommandLine=/YourSoftware\\install\.bat/i)
   ```
3. Rerun the query over the last 7 days and confirm the false positive is gone and nothing else dropped out.

Exclude by command line, not by parent. A parent-name exclusion such as `chrome.exe` would hide the exact attack this rule is for.

Two exclusions in the query are placeholders (`REPLACE_WITH_RMM_INSTALLER_NAME`, `REPLACE_WITH_APP_FOLDER`). They stand in for environment-specific software and show the pattern to follow.

## Status

Production
