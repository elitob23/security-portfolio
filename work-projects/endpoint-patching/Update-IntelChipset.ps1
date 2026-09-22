<#
.SYNOPSIS
    Silently installs the Dell-packaged Intel Chipset Device Software update on an endpoint,
    never reboots on its own, and prompts the logged-on user to restart when one is required.

.DESCRIPTION
    Designed for mass deployment over CrowdStrike Falcon RTR, Intune, or SCCM, where the
    script runs as SYSTEM in session 0 and cannot show a dialog by itself.

    Flow:
      1. Clean up state left behind by a previous run that has already been rebooted.
      2. Detect the installed chipset version and skip the endpoint if it is already current.
      3. Stage the Dell Update Package locally and validate its Authenticode signature
         (plus an optional SHA-256 pin).
      4. Run the package with /s only. /r is never passed, so the package cannot reboot.
      5. Map the Dell DUP exit code to a result.
      6. If a reboot is required, register two scheduled tasks:
           - a prompt task running as the interactive user that shows a Restart now / Later
             dialog at logon and every -ReminderIntervalHours until the machine restarts;
           - a cleanup task running as SYSTEM at the next startup that removes the flag and
             both tasks once the restart has happened.

    The script never forces a restart. The user decides when.

.PARAMETER PackagePath
    Path to the Dell Update Package .EXE. Local path or UNC share.
    When a UNC path is used, SYSTEM authenticates as the computer account, so the share
    must allow read for Domain Computers.

.PARAMETER TargetVersion
    Version the package installs. Used for the pre-install compliance check.

.PARAMETER ExpectedSha256
    Optional SHA-256 of the package. When supplied, a mismatch aborts the install.

.PARAMETER ReminderIntervalHours
    How often the restart prompt reappears while a restart is still pending. Default 4.

.PARAMETER Force
    Passes /f to the package, overriding a soft dependency error (DUP exit code 3),
    and bypasses the "already current" pre-check.

.PARAMETER DetectOnly
    Reports the detected version and exits without installing.

.PARAMETER SkipSignatureCheck
    Skips Authenticode validation. Only for lab use with a repackaged binary.

.EXAMPLE
    .\Update-IntelChipset.ps1 -PackagePath '\\fileserver\pkg$\Intel-Chipset_TH1TK_WIN64_10.1.20404.8794_A03_01.EXE'

.EXAMPLE
    .\Update-IntelChipset.ps1 -PackagePath 'C:\Windows\Temp\chipset.EXE' -DetectOnly

.NOTES
    Exit codes returned by this script:
      0     Compliant or installed, no restart needed
      3010  Installed, restart pending, user prompted
      1     Install failed
      2     Not running elevated
      5     Package is not compatible with this hardware / OS
      other Dell DUP exit code passed through
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [string]$PackagePath,

    [version]$TargetVersion = '10.1.20404.8794',

    [string]$ExpectedSha256,

    [ValidateRange(1, 72)]
    [int]$ReminderIntervalHours = 4,

    [string]$WorkRoot = "$env:ProgramData\IntelChipsetUpdate",

    [string]$LogPath,

    [switch]$Force,

    [switch]$DetectOnly,

    [switch]$SkipSignatureCheck
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paths and constants. Everything lives under a no-space path so the DUP's
# /l=<path> switch never needs quoting.
# ---------------------------------------------------------------------------
$PromptTaskName  = 'IntelChipsetUpdate-RestartPrompt'
$CleanupTaskName = 'IntelChipsetUpdate-Cleanup'
$StageDir        = Join-Path $WorkRoot 'pkg'
$FlagPath        = Join-Path $WorkRoot 'reboot-pending.json'
$StatePath       = Join-Path $WorkRoot 'installed.json'
$PromptScript    = Join-Path $WorkRoot 'Show-RestartPrompt.ps1'
$CleanupScript   = Join-Path $WorkRoot 'Clear-RestartPrompt.ps1'
$DupLog          = Join-Path $WorkRoot 'dup-install.log'
if (-not $LogPath) { $LogPath = Join-Path $WorkRoot 'chipset-update.log' }

foreach ($dir in @($WorkRoot, $StageDir)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Message
    try { Add-Content -Path $LogPath -Value $line -ErrorAction Stop } catch { }
    Write-Output $line
}

# Dell Update Package exit codes, taken from the package's own return-code map.
$DupExitCodes = @{
    0  = @{ Name = 'SUCCESS';                  Text = 'Installed successfully. No restart required.' }
    1  = @{ Name = 'ERROR';                    Text = 'Installation failed.' }
    2  = @{ Name = 'REBOOT_REQUIRED';          Text = 'Installed successfully. A restart is required to take effect.' }
    3  = @{ Name = 'DEP_SOFT_ERROR';           Text = 'Soft dependency error. Re-run with -Force to override.' }
    4  = @{ Name = 'DEP_HARD_ERROR';           Text = 'Hard dependency error. Another update must be applied first.' }
    5  = @{ Name = 'PLATFORM_UNSUPPORTED';     Text = 'Package is not compatible with this hardware or OS.' }
    6  = @{ Name = 'REBOOTING_SYSTEM';         Text = 'The package initiated a restart.' }
    7  = @{ Name = 'PASSWORD_REQUIRED';        Text = 'A device-specific password is required.' }
    8  = @{ Name = 'NO_DOWNGRADE';             Text = 'Installed version is the same or newer. Nothing to do.' }
    9  = @{ Name = 'REBOOT_UPDATE_PENDING';    Text = 'Installation continues after the next restart.' }
    10 = @{ Name = 'INVALID_CMDLINE_SPEC';     Text = 'Invalid command line passed to the package.' }
    11 = @{ Name = 'UNKNOWN_OPTION';           Text = 'Unsupported option passed to the package.' }
    12 = @{ Name = 'AUTHORIZATION_LEVEL';      Text = 'Insufficient privileges to run the package.' }
    13 = @{ Name = 'BITLOCKER_ERROR';          Text = 'BitLocker operation in progress or suspension failed.' }
}
$RebootCodes = @(2, 6, 9)

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------
function Get-InstalledChipsetVersion {
    <#
        Best-effort detection, highest version wins. The authoritative gate is the
        package itself, which returns NO_DOWNGRADE (8) if it is already current.
    #>
    $found = New-Object System.Collections.Generic.List[version]

    # 1. State written by a previous run of this script.
    if (Test-Path $StatePath) {
        try {
            $state = Get-Content $StatePath -Raw | ConvertFrom-Json
            if ($state.Version) { $found.Add([version]$state.Version) }
        } catch { Write-Log "Could not read prior state file: $($_.Exception.Message)" 'WARN' }
    }

    # 2. Intel INF installer keys.
    $intelKeys = @(
        'HKLM:\SOFTWARE\Intel\InfInst',
        'HKLM:\SOFTWARE\WOW6432Node\Intel\InfInst'
    )
    foreach ($key in $intelKeys) {
        if (-not (Test-Path $key)) { continue }
        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -notmatch '(?i)ver') { continue }
            $v = $null
            if ([version]::TryParse([string]$p.Value, [ref]$v)) { $found.Add($v) }
        }
    }

    # 3. Add/Remove Programs entries.
    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
            $prop = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if (-not $prop -or -not $prop.DisplayName) { return }
            if ($prop.DisplayName -notmatch '(?i)Intel.*Chipset Device Software') { return }
            $v = $null
            if ([version]::TryParse([string]$prop.DisplayVersion, [ref]$v)) { $found.Add($v) }
        }
    }

    if ($found.Count -eq 0) { return $null }
    ($found | Sort-Object -Descending)[0]
}

function Set-InstalledState {
    param([Parameter(Mandatory)][version]$Version, [Parameter(Mandatory)][int]$DupExitCode)
    [pscustomobject]@{
        Version     = $Version.ToString()
        InstalledOn = (Get-Date).ToString('o')
        DupExitCode = $DupExitCode
        Computer    = $env:COMPUTERNAME
    } | ConvertTo-Json | Set-Content -Path $StatePath -Encoding UTF8 -Force
}

# ---------------------------------------------------------------------------
# Restart prompt plumbing
# ---------------------------------------------------------------------------
function Remove-RestartPromptState {
    param([switch]$Quiet)
    foreach ($task in @($PromptTaskName, $CleanupTaskName)) {
        $existing = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
            if (-not $Quiet) { Write-Log "Removed scheduled task '$task'." }
        }
    }
    if (Test-Path $FlagPath) {
        Remove-Item $FlagPath -Force -ErrorAction SilentlyContinue
        if (-not $Quiet) { Write-Log "Cleared pending-restart flag." }
    }
}

function Write-HelperScripts {
    # Single-quoted here-strings: nothing below is expanded by the parent script.
    $promptBody = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FlagPath,
    [string]$Title = 'Restart required'
)

# Runs in the interactive user's session. Read-only by design: a standard user has
# no rights over the ProgramData state, so cleanup is left to the SYSTEM task.
if (-not (Test-Path $FlagPath)) { return }

try { $flag = Get-Content $FlagPath -Raw | ConvertFrom-Json } catch { return }

# If the machine has booted since the install, the update is already live.
$lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
if ($lastBoot -gt [datetime]::Parse($flag.InstalledOn)) { return }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = $Title
$form.Size            = New-Object System.Drawing.Size(460, 210)
$form.StartPosition   = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false
$form.TopMost         = $true

$label            = New-Object System.Windows.Forms.Label
$label.Location   = New-Object System.Drawing.Point(20, 20)
$label.Size       = New-Object System.Drawing.Size(410, 90)
$label.Text       = @"
A required chipset update has been installed on this computer.

Please restart to finish applying it. You can keep working and restart later; this reminder will reappear until you do.
"@

$restartButton          = New-Object System.Windows.Forms.Button
$restartButton.Text     = 'Restart now'
$restartButton.Size     = New-Object System.Drawing.Size(120, 30)
$restartButton.Location = New-Object System.Drawing.Point(190, 125)

$laterButton          = New-Object System.Windows.Forms.Button
$laterButton.Text     = 'Remind me later'
$laterButton.Size     = New-Object System.Drawing.Size(120, 30)
$laterButton.Location = New-Object System.Drawing.Point(315, 125)

$restartButton.Add_Click({
    $form.Close()
    # 60-second grace period so the user can save open work.
    Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
        -ArgumentList '/r', '/t', '60', '/c', 'Restarting to finish a chipset update.' `
        -WindowStyle Hidden
})
$laterButton.Add_Click({ $form.Close() })

$form.Controls.AddRange(@($label, $restartButton, $laterButton))
$form.AcceptButton = $restartButton
$null = $form.ShowDialog()
'@

    $cleanupBody = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FlagPath,
    [Parameter(Mandatory)][string]$PromptTaskName,
    [Parameter(Mandatory)][string]$CleanupTaskName,
    [string]$LogPath
)

# Runs as SYSTEM at startup. Reaching this point means the machine has restarted,
# so the pending update is applied and all prompt state can go away.
if ($LogPath) {
    $line = "[{0}] [OK] Restart completed. Removing restart prompt state." -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    try { Add-Content -Path $LogPath -Value $line -ErrorAction Stop } catch { }
}

Remove-Item $FlagPath -Force -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $PromptTaskName  -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $CleanupTaskName -Confirm:$false -ErrorAction SilentlyContinue
'@

    Set-Content -Path $PromptScript  -Value $promptBody  -Encoding UTF8 -Force
    Set-Content -Path $CleanupScript -Value $cleanupBody -Encoding UTF8 -Force
}

function Register-RestartPrompt {
    param([Parameter(Mandatory)][datetime]$InstalledOn)

    [pscustomobject]@{
        InstalledOn = $InstalledOn.ToString('o')
        Version     = $TargetVersion.ToString()
        Computer    = $env:COMPUTERNAME
    } | ConvertTo-Json | Set-Content -Path $FlagPath -Encoding UTF8 -Force

    Write-HelperScripts

    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

    # Prompt task: runs as whichever standard user is logged on, so the dialog
    # lands in their desktop session instead of session 0.
    $promptAction = New-ScheduledTaskAction -Execute $psExe -Argument (
        '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass ' +
        "-File `"$PromptScript`" -FlagPath `"$FlagPath`""
    )
    $logonTrigger  = New-ScheduledTaskTrigger -AtLogOn
    $repeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) `
        -RepetitionInterval (New-TimeSpan -Hours $ReminderIntervalHours) `
        -RepetitionDuration ([TimeSpan]::FromDays(365))
    $promptTriggers = @($logonTrigger, $repeatTrigger)
    $promptPrincipal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited
    $promptSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit ([TimeSpan]::Zero)

    Register-ScheduledTask -TaskName $PromptTaskName -Action $promptAction `
        -Trigger $promptTriggers -Principal $promptPrincipal -Settings $promptSettings `
        -Description 'Prompts the logged-on user to restart after an Intel chipset update.' `
        -Force | Out-Null
    Write-Log "Registered '$PromptTaskName' (at logon, then every $ReminderIntervalHours h)." 'OK'

    # Cleanup task: SYSTEM, at startup. Tears everything down once the restart happens.
    $cleanupAction = New-ScheduledTaskAction -Execute $psExe -Argument (
        '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass ' +
        "-File `"$CleanupScript`" -FlagPath `"$FlagPath`" " +
        "-PromptTaskName `"$PromptTaskName`" -CleanupTaskName `"$CleanupTaskName`" " +
        "-LogPath `"$LogPath`""
    )
    $cleanupPrincipal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -RunLevel Highest
    $cleanupSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $CleanupTaskName -Action $cleanupAction `
        -Trigger (New-ScheduledTaskTrigger -AtStartup) -Principal $cleanupPrincipal `
        -Settings $cleanupSettings `
        -Description 'Removes the Intel chipset restart prompt once the endpoint has restarted.' `
        -Force | Out-Null
    Write-Log "Registered '$CleanupTaskName' (at next startup)." 'OK'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Write-Log '================================================================'
Write-Log "Intel Chipset Device Software update started on $env:COMPUTERNAME"
Write-Log "Target version: $TargetVersion | Running as: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log 'Not running elevated. Re-run as administrator or SYSTEM.' 'ERROR'
    exit 2
}

# Stale state from a run that has already been rebooted.
if (Test-Path $FlagPath) {
    try {
        $oldFlag  = Get-Content $FlagPath -Raw | ConvertFrom-Json
        $lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        if ($lastBoot -gt [datetime]::Parse($oldFlag.InstalledOn)) {
            Write-Log 'Endpoint has restarted since the last install. Clearing old prompt state.'
            Remove-RestartPromptState
        }
        else {
            Write-Log 'A restart from a previous run is still pending on this endpoint.' 'WARN'
        }
    } catch {
        Write-Log "Could not evaluate existing flag file, clearing it: $($_.Exception.Message)" 'WARN'
        Remove-RestartPromptState -Quiet
    }
}

$installed = Get-InstalledChipsetVersion
if ($installed) { Write-Log "Detected installed chipset version: $installed" }
else            { Write-Log 'No installed chipset version detected. The package will decide.' 'WARN' }

if ($DetectOnly) {
    Write-Log 'DetectOnly: no changes made.' 'OK'
    exit 0
}

if ($installed -and $installed -ge $TargetVersion -and -not $Force) {
    Write-Log "Already at $installed (target $TargetVersion). Endpoint is compliant." 'OK'
    exit 0
}

# --- Stage and validate the package -----------------------------------------
if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
    Write-Log "Package not found at '$PackagePath'." 'ERROR'
    exit 1
}

$localPackage = Join-Path $StageDir (Split-Path $PackagePath -Leaf)
try {
    $sourceFull = (Resolve-Path -LiteralPath $PackagePath).ProviderPath
    if ($sourceFull -eq $localPackage) {
        Write-Log "Package is already staged at '$localPackage'."
    }
    else {
        Copy-Item -LiteralPath $PackagePath -Destination $localPackage -Force
        Write-Log "Staged package to '$localPackage'."
    }
} catch {
    Write-Log "Failed to stage package: $($_.Exception.Message)" 'ERROR'
    exit 1
}

if ($ExpectedSha256) {
    $actual = (Get-FileHash -LiteralPath $localPackage -Algorithm SHA256).Hash
    if ($actual -ne $ExpectedSha256.Replace('-', '').Trim().ToUpperInvariant()) {
        Write-Log "SHA-256 mismatch. Expected $ExpectedSha256, got $actual. Aborting." 'ERROR'
        Remove-Item $localPackage -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Log 'SHA-256 matches the expected value.' 'OK'
}

if (-not $SkipSignatureCheck) {
    $sig = Get-AuthenticodeSignature -LiteralPath $localPackage
    if ($sig.Status -ne 'Valid') {
        Write-Log "Authenticode status is '$($sig.Status)'. Aborting." 'ERROR'
        Remove-Item $localPackage -Force -ErrorAction SilentlyContinue
        exit 1
    }
    $subject = $sig.SignerCertificate.Subject
    if ($subject -notmatch '(?i)Dell (Inc|Technologies)') {
        Write-Log "Package is signed by an unexpected publisher: $subject. Aborting." 'ERROR'
        Remove-Item $localPackage -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Log "Signature valid, signed by: $subject" 'OK'
}

# --- Install -----------------------------------------------------------------
# /s  = silent. /f = override soft dependency errors.
# /r is deliberately never passed, so the package cannot restart the endpoint.
$dupArgs = @('/s', "/l=$DupLog")
if ($Force) { $dupArgs += '/f' }

if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Install Intel Chipset $TargetVersion silently")) {
    Write-Log 'WhatIf: install skipped, no changes made.' 'WARN'
    exit 0
}

Write-Log "Running: `"$localPackage`" $($dupArgs -join ' ')"
$installedOn = Get-Date
try {
    $proc = Start-Process -FilePath $localPackage -ArgumentList $dupArgs -Wait -PassThru -WindowStyle Hidden
    $code = $proc.ExitCode
} catch {
    Write-Log "Failed to launch the package: $($_.Exception.Message)" 'ERROR'
    exit 1
}

$result = $DupExitCodes[$code]
if ($result) { Write-Log "Package returned $code ($($result.Name)): $($result.Text)" }
else         { Write-Log "Package returned an undocumented exit code: $code" 'WARN' }
Write-Log "Package log: $DupLog"

Remove-Item $localPackage -Force -ErrorAction SilentlyContinue

switch ($code) {
    0 {
        Set-InstalledState -Version $TargetVersion -DupExitCode $code
        Write-Log 'Chipset update complete. No restart required.' 'OK'
        exit 0
    }
    8 {
        Write-Log 'Endpoint already at this version or newer. Nothing to do.' 'OK'
        exit 0
    }
    { $_ -in $RebootCodes } {
        Set-InstalledState -Version $TargetVersion -DupExitCode $code
        if ($code -eq 6) {
            Write-Log 'Package reported it initiated a restart, which should not happen without /r. Investigate.' 'ERROR'
        }
        try {
            Register-RestartPrompt -InstalledOn $installedOn
            Write-Log 'Install complete. Endpoint NOT restarted; the user will be prompted.' 'OK'
        } catch {
            Write-Log "Install succeeded but the restart prompt could not be registered: $($_.Exception.Message)" 'ERROR'
            Write-Log 'Restart is still pending and must be driven manually.' 'WARN'
        }
        exit 3010
    }
    3 {
        Write-Log 'Soft dependency error. Re-run with -Force if the dependency is acceptable.' 'ERROR'
        exit 3
    }
    5 {
        Write-Log 'Package is not applicable to this endpoint. Exclude it from the deployment.' 'WARN'
        exit 5
    }
    default {
        Write-Log 'Install did not succeed. Endpoint was not restarted.' 'ERROR'
        exit ($code -as [int])
    }
}
