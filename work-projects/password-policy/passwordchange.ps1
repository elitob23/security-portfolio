## 0. IMPORT ACTIVE DIRECTORY MODULE ""
Import-Module ActiveDirectory
# 1. CONFIGURATION
# Where to start the search
$TargetOU = "OU=User Accounts, DC=contoso,DC=com"
# Any OUs that the script will completely ignore
$ExcludedOUs = @(""
    #Start Service OUs here#
)
# Specific usernames to skip
$ExcludedUsers = @(""
)
# Group names whose members should be skipped - NO GROUPS ARE TARGETED, FINE IF ITS BLANK
$ExcludedGroups = @()
# CSV output path
$CsvOutputPath = "C:\Temp\PasswordRollout_$(Get-Date -Format 'yyyy-MM-dd_HHmm').csv"
# 2. BUILD THE EXCLUSION LISTS
# Gather all members of the excluded groups
$GroupExclusions = foreach ($Group in $ExcludedGroups) {
    Get-ADGroupMember -Identity $Group -Recursive -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SamAccountName
}
# Create a master list of usernames to ignore
$FinalUserExclusionList = ($ExcludedUsers + $GroupExclusions) | Select-Object -Unique
# 3. GET AND FILTER USERS
# 1. Get all active users in the Target OU
# 2. Filter out users who are in the Excluded OUs
# 3. Filter out users who are in the Final User Exclusion List
$UsersToChange = Get-ADUser -Filter 'Enabled -eq $true' -SearchBase $TargetOU -SearchScope Subtree -Properties SamAccountName, PasswordNeverExpires, DistinguishedName |
    Where-Object {
        $userDN = $_.DistinguishedName
        $isExcludedOU = $false
        # Check if user lives in any of the excluded OUs
        foreach ($ou in $ExcludedOUs) {
            if ($userDN -like "*$ou*") { $isExcludedOU = $true; break }
        }
        # User is kept ONLY if NOT in excluded OU AND NOT in excluded user list
        ($isExcludedOU -eq $false) -and ($FinalUserExclusionList -notcontains $_.SamAccountName)
    }
Write-Host "Found $($UsersToChange.Count) users to update."
# 4. EXECUTION
$CsvResults = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($User in $UsersToChange) {
    $NeverExpiresFix = $false
    # Fix the Never Expires conflict if it exists
    if ($User.PasswordNeverExpires -eq $true) {
        Write-Host "Clearing PasswordNeverExpires for: $($User.SamAccountName)"
        Set-ADUser -Identity $User.SamAccountName -PasswordNeverExpires $false
        $NeverExpiresFix = $true
    }
    # Set the flag for next login
    Set-ADUser -Identity $User.SamAccountName -ChangePasswordAtLogon $true
    $CsvResults.Add([PSCustomObject]@{
        SamAccountName       = $User.SamAccountName
        DistinguishedName    = $User.DistinguishedName
        NeverExpiresCleaned  = $NeverExpiresFix
        ChangeAtLogonSet     = $true
        Timestamp            = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    })
}
# 5. EXPORT CSV
if ($CsvResults.Count -gt 0) {
    $CsvResults | Export-Csv -Path $CsvOutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "CSV exported to: $CsvOutputPath"
} else {
    Write-Host "No users were processed. CSV not created."
}
Write-Host "NeverExpires conflicts found: $(($CsvResults | Where-Object { $_.NeverExpiresCleaned -eq $true }).Count)"
Start-ADSyncSyncCycle -PolicyType Delta
