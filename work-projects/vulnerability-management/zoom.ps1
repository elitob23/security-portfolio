[System.Collections.ArrayList]$UserArray = (Get-ChildItem C:\Users\).Name

$UserArray.Remove('Public')

 

New-PSDrive HKU Registry HKEY_USERS

Foreach($obj in $UserArray){

    $Parent  = "$env:SystemDrive\users\$obj\Appdata\Roaming"

    $Path = Test-Path -Path (Join-Path $Parent 'zoom\bin\zoom.exe')

    if($Path){

        "Zoom is installed for user $obj"

        $User = New-Object System.Security.Principal.NTAccount($obj)

        $sid = $User.Translate([System.Security.Principal.SecurityIdentifier]).value

        if(test-path "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZoomUMX"){

            "Removing registry key ZoomUMX for $sid on HK_Users"

            Remove-Item "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZoomUMX" -Force

        }

        "Removing folder on $Parent"

        Remove-item -Recurse -Path (join-path $Parent 'zoom') -Force -Confirm:$false

        "Removing start menu shortcut"

        Remove-item -recurse -Path (Join-Path $Parent '\Microsoft\Windows\Start Menu\Programs\zoom') -Force -Confirm:$false

    }

    else{

        "Zoom is not installed for user $obj"

    }

}

Remove-PSDrive HKU
