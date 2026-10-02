[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$LogPath = "$env:ProgramData\OfficeRemediation\CVE-2017-0199_Office2007_Removal.log"
)

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Level = 'INFO'
    )
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line  = "[$stamp] [$Level] $Message"
    try { Add-Content -Path $LogPath -Value $line -ErrorAction Stop } catch { }
    Write-Output $line
}

$logDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

Write-Log "================================================================"
Write-Log "CVE-2017-0199 / Office 2007 removal started on $env:COMPUTERNAME"
Write-Log "Running as: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "Script is not running elevated. Re-run as administrator / SYSTEM." 'ERROR'
    exit 2
}

function Get-Office2007Products {
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $found = foreach ($path in $uninstallPaths) {
        if (-not (Test-Path $path)) { continue }
        Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
            $key  = $_
            $prop = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            if (-not $prop) { return }
            $childName   = $key.PSChildName
            $displayName = $prop.DisplayName
            $codeMatch = $childName -match '^\{9012[0-9A-Fa-f]{4}-.*-0000000FF1CE\}$'
            $nameMatch = ($displayName -match 'Microsoft Office.*2007') -or ($displayName -match '2007 Microsoft Office')
            if ($codeMatch -or $nameMatch) {
                [pscustomobject]@{
                    DisplayName     = $displayName
                    DisplayVersion  = $prop.DisplayVersion
                    ProductKey      = $childName
                    UninstallString = $prop.UninstallString
                }
            }
        }
    }
    $found | Sort-Object ProductKey -Unique
}

function Get-Office2007FileSystemResidue {
    $roots = @(
        "$env:ProgramFiles\Microsoft Office\Office12",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office12"
    ) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($root in $roots) {
        $exes = Get-ChildItem -Path $root -Filter '*.exe' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(winword|excel|powerpnt|outlook|msaccess|onenote|mspub|visio|winproj)\.exe$' }
        if ($exes) {
            [pscustomobject]@{ Path = $root; Binaries = ($exes.Name -join ', ') }
        }
    }
}

# Sets $script:UnExit and logs progress. Does NOT emit objects to the pipeline.
function Invoke-Office2007Uninstall {
    param([Parameter(Mandatory)]$Product)

    $script:UnExit = -1
    $name  = $Product.DisplayName
    $unStr = $Product.UninstallString

    if ([string]::IsNullOrWhiteSpace($unStr)) {
        Write-Log "No UninstallString for '$name' - skipping." 'WARN'
        return
    }

    # Path A: Office suite setup.exe + silent config.xml
    if ($unStr -match '(?i)"?(?<exe>[^"]*setup\.exe)"?\s+/uninstall\s+(?<rid>\S+)') {
        $setupExe  = $matches['exe']
        $releaseId = $matches['rid']
        if (Test-Path $setupExe) {
            # Config written to a no-space path to avoid argument quoting issues.
            $cfgPath = Join-Path $env:windir 'Temp\Office2007_Uninstall.xml'
            $cfgXml = @"
<Configuration Product="$releaseId">
  <Display Level="none" CompletionNotice="no" SuppressModal="yes" AcceptEula="yes" />
  <Setting Id="SETUP_REBOOT" Value="Never" />
</Configuration>
"@
            Set-Content -Path $cfgPath -Value $cfgXml -Encoding ASCII -Force
            Write-Log "Uninstalling '$name' via setup.exe (ReleaseID: $releaseId)..."
            if ($PSCmdlet.ShouldProcess($name, "Silent uninstall via setup.exe")) {
                $proc = Start-Process -FilePath $setupExe -ArgumentList "/uninstall $releaseId /config $cfgPath" -Wait -PassThru -WindowStyle Hidden
                $script:UnExit = $proc.ExitCode
                Remove-Item $cfgPath -Force -ErrorAction SilentlyContinue
                Write-Log "setup.exe returned exit code $($proc.ExitCode) for '$name'."
            }
            else {
                $script:UnExit = 0
            }
            return
        }
        else {
            Write-Log "setup.exe not found at '$setupExe' for '$name'." 'WARN'
        }
    }

    # Path B: plain MSI fallback
    if ($Product.ProductKey -match '^\{[0-9A-Fa-f-]{36}\}$') {
        $guid = $Product.ProductKey
        Write-Log "Uninstalling '$name' via msiexec ($guid)..."
        if ($PSCmdlet.ShouldProcess($name, "Silent uninstall via msiexec /x")) {
            $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/x $guid /qn /norestart REBOOT=ReallySuppress" -Wait -PassThru -WindowStyle Hidden
            $script:UnExit = $proc.ExitCode
            Write-Log "msiexec returned exit code $($proc.ExitCode) for '$name'."
        }
        else {
            $script:UnExit = 0
        }
        return
    }

    Write-Log "Could not determine a silent uninstall method for '$name'." 'WARN'
}

$products = Get-Office2007Products
if (-not $products) {
    Write-Log "No Microsoft Office 2007 components detected. Machine is compliant." 'OK'
    exit 0
}

Write-Log "Detected $($products.Count) Office 2007 component(s):"
foreach ($p in $products) {
    Write-Log ("  - {0}  [v{1}]  Key: {2}" -f $p.DisplayName, $p.DisplayVersion, $p.ProductKey)
}

if ($WhatIfPreference) {
    Write-Log "WhatIf mode: no changes were made. The above would be removed." 'WARN'
    exit 0
}

$rebootRequired = $false
foreach ($p in $products) {
    Invoke-Office2007Uninstall -Product $p
    switch ($script:UnExit) {
        0     { Write-Log ("Removed: {0}" -f $p.DisplayName) 'OK' }
        3010  { Write-Log ("Removed (reboot pending): {0}" -f $p.DisplayName) 'OK'; $rebootRequired = $true }
        default { Write-Log ("Uninstall returned non-success ({0}): {1}" -f $script:UnExit, $p.DisplayName) 'WARN' }
    }
}

Write-Log "Double-checking removal (pass 1: registry, pass 2: filesystem)..."
Start-Sleep -Seconds 5
$remainingReg = Get-Office2007Products
$remainingFs  = Get-Office2007FileSystemResidue
$regClean = -not $remainingReg
$fsClean  = -not $remainingFs

if ($regClean) { Write-Log "Pass 1 (registry): CLEAN." 'OK' }
else {
    Write-Log "Pass 1 (registry): still present:" 'ERROR'
    foreach ($p in $remainingReg) { Write-Log ("    - {0}  Key: {1}" -f $p.DisplayName, $p.ProductKey) 'ERROR' }
}
if ($fsClean) { Write-Log "Pass 2 (filesystem): CLEAN." 'OK' }
else {
    Write-Log "Pass 2 (filesystem): residual files:" 'ERROR'
    foreach ($f in $remainingFs) { Write-Log ("    - {0}  ->  {1}" -f $f.Path, $f.Binaries) 'ERROR' }
}

if ($regClean -and $fsClean) {
    Write-Log "VERIFIED by BOTH checks: Office 2007 is fully removed." 'OK'
    if ($rebootRequired) {
        Write-Log "Windows reports a reboot is PENDING. The script did NOT restart the machine. Exit 3010." 'WARN'
        exit 3010
    }
    exit 0
}
else {
    Write-Log "VERIFICATION FAILED: Office 2007 still detected. The script did NOT restart the machine." 'ERROR'
    Write-Log "Escalate to Microsoft SaRA or the legacy OffScrub script." 'WARN'
    exit 1
}
