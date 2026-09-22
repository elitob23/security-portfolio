# Intel Chipset Device Software — Fleet Update

PowerShell deployment script for the Dell-packaged **Intel Chipset Device Software 10.1.20404.8794 (A03)**.
Installs silently, **never restarts the endpoint itself**, and hands the restart decision to the user
through a dialog that reappears until the machine is actually rebooted.

Built for push from **CrowdStrike Falcon RTR**, Intune, or SCCM, where the script executes as SYSTEM.

| File | Purpose |
|---|---|
| [`Update-IntelChipset.ps1`](Update-IntelChipset.ps1) | The deployment script. Self-contained — it writes its own helper scripts at runtime. |

## The restart problem

The script runs as SYSTEM in **session 0**. Nothing it draws on screen is visible to the person at the
keyboard. So it does not try to. Instead, when the package reports that a restart is required, it lays
down two scheduled tasks:

| Task | Runs as | Trigger | Job |
|---|---|---|---|
| `IntelChipsetUpdate-RestartPrompt` | `BUILTIN\Users`, limited | At logon, then every *N* hours | Shows the Restart now / Remind me later dialog in the user's own desktop session |
| `IntelChipsetUpdate-Cleanup` | `SYSTEM`, highest | At startup | Removes the flag and both tasks once the restart has happened |

Think of it as leaving a sticky note on the monitor instead of shouting from the basement. The prompt task
is read-only by design — a standard user has no rights over the state in `ProgramData`, so teardown is left
to the SYSTEM task, which only ever fires *after* a reboot has already occurred.

Choosing **Restart now** runs `shutdown /r /t 60` so there is a minute to save open work. Choosing
**Remind me later** does nothing at all. There is no forced-restart deadline in this script.

## How it works

1. **Reconcile prior state.** If a flag from an earlier run exists and `LastBootUpTime` is newer than the
   recorded install time, the restart already happened — clear the flag and tasks.
2. **Detect.** Reads, in order: state written by a previous run, `HKLM:\SOFTWARE\[WOW6432Node\]Intel\InfInst`,
   and Add/Remove Programs entries matching `Intel*Chipset Device Software`. Highest version wins.
   Already at or above the target → exit 0, nothing touched.
3. **Stage and validate.** Copies the package to `C:\ProgramData\IntelChipsetUpdate\pkg` (a no-space path,
   so the DUP's `/l=<path>` switch never needs quoting), then checks the Authenticode signature is `Valid`
   and the signer is Dell. Optional `-ExpectedSha256` pin on top.
4. **Install.** Runs the package with `/s` (and `/f` only if `-Force`). **`/r` is never passed** — that switch
   is the only thing that makes a Dell Update Package reboot, so withholding it is what guarantees the
   endpoint stays up.
5. **Map the result.** The package's own return codes drive the outcome (table below).
6. **Prompt.** On a reboot code, register the two tasks and exit `3010`.

Detection is best-effort — Intel's 10.1.x chipset packages are INF-only and do not always leave a tidy
Add/Remove entry. That is fine: the authoritative gate is the package itself, which returns
`NO_DOWNGRADE` (8) if the endpoint is already current, and the script treats that as a clean no-op.

## Usage

```powershell
# Standard deployment from a share
.\Update-IntelChipset.ps1 -PackagePath '\\fileserver\pkg$\Intel-Chipset_TH1TK_WIN64_10.1.20404.8794_A03_01.EXE'

# Pin the binary by hash (recommended when staging from a share)
.\Update-IntelChipset.ps1 -PackagePath '\\fileserver\pkg$\chipset.EXE' `
    -ExpectedSha256 '078E0D7B449BDF2AD2C45015AE22DA6CCBAC8C7A8EEDC5F8CE3E4A2DBAA16EE6'

# Inventory pass — report the installed version, change nothing
.\Update-IntelChipset.ps1 -PackagePath 'C:\Windows\Temp\chipset.EXE' -DetectOnly

# Dry run
.\Update-IntelChipset.ps1 -PackagePath 'C:\Windows\Temp\chipset.EXE' -WhatIf

# Nag every hour instead of every four
.\Update-IntelChipset.ps1 -PackagePath 'C:\Windows\Temp\chipset.EXE' -ReminderIntervalHours 1
```

### Parameters

| Parameter | Default | Notes |
|---|---|---|
| `-PackagePath` | *required* | Local or UNC path to the Dell `.EXE`. |
| `-TargetVersion` | `10.1.20404.8794` | Used only for the pre-install compliance check. |
| `-ExpectedSha256` | *none* | Mismatch aborts the install. |
| `-ReminderIntervalHours` | `4` | How often the restart prompt returns. 1–72. |
| `-WorkRoot` | `C:\ProgramData\IntelChipsetUpdate` | Staging, logs, state, helper scripts. |
| `-LogPath` | `<WorkRoot>\chipset-update.log` | Script log. The package writes its own to `<WorkRoot>\dup-install.log`. |
| `-Force` | off | Adds `/f` and bypasses the "already current" pre-check. |
| `-DetectOnly` | off | Report and exit. |
| `-SkipSignatureCheck` | off | Lab use only. |

## Exit codes

The script's own codes:

| Code | Meaning |
|---|---|
| `0` | Compliant, or installed with no restart needed |
| `3010` | Installed, restart pending, user prompted |
| `1` | Install failed |
| `2` | Not running elevated |
| `3` | Soft dependency error — re-run with `-Force` |
| `5` | Package not applicable to this endpoint |

`3010` is the standard "soft reboot required" signal, so Intune and SCCM read it correctly without extra
configuration. In Falcon RTR, treat `0` and `3010` as success and everything else as a failed host.

The underlying Dell Update Package return codes, read out of the package's own return-code map:

| Code | Name | Handling |
|---|---|---|
| `0` | `SUCCESS` | Done, no restart |
| `1` | `ERROR` | Fail the host |
| `2` | `REBOOT_REQUIRED` | Register prompt, exit 3010 |
| `3` | `DEP_SOFT_ERROR` | Fail, suggest `-Force` |
| `4` | `DEP_HARD_ERROR` | Fail — another update is a prerequisite |
| `5` | `PLATFORM_UNSUPPORTED` | Exclude the host from the deployment |
| `6` | `REBOOTING_SYSTEM` | Logged as an error — should be impossible without `/r` |
| `7` | `PASSWORD_REQUIRED` | Fail |
| `8` | `NO_DOWNGRADE` | Already current, treated as success |
| `9` | `REBOOT_UPDATE_PENDING` | Register prompt, exit 3010 |
| `10` | `INVALID_CMDLINE_SPEC` | Fail |
| `11` | `UNKNOWN_OPTION` | Fail |
| `12` | `AUTHORIZATION_LEVEL` | Fail — not elevated |
| `13` | `BITLOCKER_ERROR` | Fail |

## Deployment notes

- **Run 64-bit.** The package is `WIN64`. Under a 32-bit PowerShell host the registry detection reads the
  wrong view. Falcon RTR's `runscript` is 64-bit; Intune needs *Run script in 64-bit PowerShell host = Yes*.
- **UNC sources.** As SYSTEM the endpoint authenticates with its **computer account**, so the share must
  grant read to `Domain Computers`. Copying the package down first and passing a local path avoids the
  question entirely, and is the better option for RTR (`put` the file, then `runscript`).
- **Pilot first.** Ring the deployment: a handful of each hardware model before the fleet. Chipset INF
  updates touch low-level device bindings; a bad model-specific interaction is cheaper to find on ten
  machines than on three hundred.
- **Verify by re-running with `-DetectOnly`** after the restart wave, or collect
  `C:\ProgramData\IntelChipsetUpdate\installed.json` across the fleet.
- **Uninstalling the prompt early.** If a restart wave needs to be called off:
  ```powershell
  Unregister-ScheduledTask -TaskName IntelChipsetUpdate-RestartPrompt -Confirm:$false
  Unregister-ScheduledTask -TaskName IntelChipsetUpdate-Cleanup -Confirm:$false
  Remove-Item C:\ProgramData\IntelChipsetUpdate\reboot-pending.json -Force
  ```

## Package reference

| | |
|---|---|
| Product | Intel(R) Chipset Device Software |
| Version | 10.1.20404.8794 |
| Dell revision | A03 |
| Dell package ID | TH1TK |
| Architecture | WIN64 |
| SHA-256 | `078E0D7B449BDF2AD2C45015AE22DA6CCBAC8C7A8EEDC5F8CE3E4A2DBAA16EE6` |

> The hash above is of the specific binary this script was written against. Re-verify it against Dell's
> published checksum before trusting it in production, and re-pin whenever the package revision changes.
