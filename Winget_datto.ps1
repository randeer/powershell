#region Functions & Variables-------------------------------------------------------------------------------------------------------

$varDebug=$false
$varProgData=$((get-process aemagent).path | split-path | split-path)
[int]$script:varError=0
[int]$varEmpty=0
$varEpoch=Get-Date -UFormat %s

function showBarrier {
    write-host "==================================="
}

#function to verify known error codes...............................................................................................
$arrErrors=@{
             "0"=[psCustomObject]@{Message="Package installed/updated OK";                                                          isError=$false}
    "0x800704C7"=[psCustomObject]@{Message="Package installation was declined via userland UAC prompt";                             isError=$false} #undocumented!
    "0x8A150001"=[psCustomObject]@{Message="An internal error occurred";                                                            isError=$true}
    "0x8A150002"=[psCustomObject]@{Message="Invalid command line arguments. Component error; please contact Support";               isError=$true}
    "0x8A150003"=[psCustomObject]@{Message="Executing command failed";                                                              isError=$true}
    "0x8A150008"=[psCustomObject]@{Message="Failed to download installer. Please ensure device is able to access download location";isError=$true}
    "0x8A15000A"=[psCustomObject]@{Message="The index is corrupt";                                                                  isError=$true}
    "0x8A150010"=[psCustomObject]@{Message="No available installers for this ID are applicable for this system";                    isError=$false}
    "0x8A150011"=[psCustomObject]@{Message="Installer file's hash does not match manifest. Likely a transient error for this ID";   isError=$true}
    "0x8A150014"=[psCustomObject]@{Message="ID not found: [Install] Bad ID supplied (error) :: [Update] App is not installed (OK)"; isError=$false} #this one will be quite popular.
    "0x8A150015"=[psCustomObject]@{Message="No sources are configured to download from. WinGet configuration issue";                isError=$true}
    "0x8A150016"=[psCustomObject]@{Message="Multiple packages found matching criteria. Please refine app ID selection";             isError=$true}
    "0x8A150019"=[psCustomObject]@{Message="Command requires administrator privileges to run";                                      isError=$true}
    "0x8A15002B"=[psCustomObject]@{Message="No applicable update found. App is up-to-date";                                         isError=$false}
    "0x8A150035"=[psCustomObject]@{Message="Package ID not found. Please refine app ID selection";                                  isError=$true}
    "0x8A150065"=[psCustomObject]@{Message="Application failed to install. Likely a transient error for this ID";                   isError=$true}
    "0x8A160099"=[psCustomObject]@{Message="Package was despatched using an uncivil matrix. Please recalibrate matrices.";          isError=$true}
    "0x8A150075"=[psCustomObject]@{Message="Authentication failed";                                                                 isError=$true}
    "0x8A150076"=[psCustomObject]@{Message="Authentication failed. Interactive authentication required";                            isError=$true}
    "0x8A150077"=[psCustomObject]@{Message="Authentication failed. User cancelled";                                                 isError=$false}
    "0x8A150078"=[psCustomObject]@{Message="Authentication failed. Authenticated account is not the desired account";               isError=$true}
    "0x8A150101"=[psCustomObject]@{Message="Application is currently running. Exit the application then try again";                 isError=$false}
    "0x8A150102"=[psCustomObject]@{Message="Another installation is already in progress";                                           isError=$false}
    "0x8A150104"=[psCustomObject]@{Message="System is missing a dependency required for application to install";                    isError=$true}
    "0x8A150105"=[psCustomObject]@{Message="Insufficient disk space to perform operation";                                          isError=$true}
    "0x8A150106"=[psCustomObject]@{Message="Insufficient memory to perform operation";                                              isError=$false}
    "0x8A150109"=[psCustomObject]@{Message="Installation succeeded; Restart is required";                                           isError=$false}
    "0x8A15010A"=[psCustomObject]@{Message="Installation failed; A restart is advised";                                             isError=$true}
    "0x8A15010D"=[psCustomObject]@{Message="Another version of this application is already installed";                              isError=$true}
    "0x8A15010E"=[psCustomObject]@{Message="A higher version of this application is already installed";                             isError=$false}
    "0x8A150111"=[psCustomObject]@{Message="Application is currently in use by another application";                                isError=$false}
    "0x8A150113"=[psCustomObject]@{Message="Package not supported by system";                                                       isError=$true}
}

function checkError ($errorCode, $winGetID, $operation) {
    $errorCode=([int]$errorCode).toString("X")
    if ($arrErrors["$errorCode"]) {
        if (($arrErrors["$errorCode"]).isError) {
            write-host "! ERROR: $operation operation for $winGetID failed with code $errorCode`:"
            write-host "  $(($arrErrors["$errorCode"]).Message)."
            $script:varError=1
        } else {
            write-host "- OK: $operation operation for $winGetID concluded with code $errorCode`:"
            write-host "  $(($arrErrors["$errorCode"]).Message)."
        }
    } else {
        write-host "! ERROR: $operation operation for $winGetID failed with code $errorCode."
        $script:varError=1
    }

    #awkward post-summary summary for cases where all apps were updated and between 'one' and 'all' failed
    if ($winGetID -eq 'ALL') {
        write-host `r
        write-host "- Postscript: The command was given to update 'ALL' apps, and the 'ALL' command failed."
        write-host "  All updates -may- have failed, or just one of multiple, but the nature of the command"
        write-host "  means that the only ID supplied was 'ALL', and only one code was received back from it."
        write-host "  It is suggested to break down the 'ALL' command into individual apps to see which is"
        write-host "  failing and for what reason in greater detail."
        write-host `r
    }
}

function cdPnt ($codepoint) {
    return $([Convert]::ToChar([int][Convert]::ToInt32($codepoint, 16)))
}

function doCleanup {
    if (!($varDebug)) {
        gci "$env:PUBLIC\CentraStage\*.txt" | % {remove-item $($_.FullName) -Force | out-null}
    }
}

#ready lets go......................................................................................................................

write-host "WinGet v2"
showBarrier

if ($varDebug) {
    write-host "! NOTICE: Debug mode is enabled."
    write-host "  This causes log files in $env:PUBLIC\CentraStage to be retained."
    write-host "  Following each run with debug mode enabled, please delete these files manually."
    write-host "  Otherwise, the Component will re-parse them and output the results to Stdout."
    showBarrier
}

#region Is This Job-Run Valid?------------------------------------------------------------------------------------------------------

if ($(whoami) -notmatch 'nt authority\\system') {
    write-host "! ERROR: Job has been scheduled and configured to run as the logged-in user."
    write-host "  This Component has been designed to run as the system user, from the vantage point"
    write-host "  of which code will then be launched automatically as the logged-in user."
    write-host "  The attention to detail is appreciated, but not necessary; try a Quick Job instead."
    write-host "- Execution cannot continue. Exiting."
    exit 1
}

#region Is This System Valid?-------------------------------------------------------------------------------------------------------

if (((7..10),(12..15),(17..25),(29..46),(50..56),(59..64),72,76,77,79,80,95,96,109,110,120,(143..148),159,160,168,169 | write-output) -contains $((gwmi win32_operatingsystem).operatingsystemsku)) {
    if ((gwmi win32_operatingsystem).buildnumber -lt 26100) {
        write-host "! ERROR: WinGet cannot be installed on Windows Server versions prior to 2025."
        write-host "  More info: https://github.com/microsoft/winget-cli/discussions/2361"
        write-host "  Execution cannot continue. Exiting."
        exit 1
    }
} else {
    if ((gwmi win32_operatingsystem).buildnumber -lt 17763) {
        write-host "! ERROR: WinGet requires a minimum operating system of Windows 10 version 1809 (17763)."
        write-host "  Execution cannot continue. Exiting."
        exit 1
    }
}

#region Is a User Logged On?--------------------------------------------------------------------------------------------------------

if (!((gwmi -Class Win32_Computersystem).Username)) {
    write-host "! NOTICE: No users are logged onto the system."
    write-host "  WinGet works on the user-level; this Component masquerades as the logged-on user."
    write-host "  Operation cannot continue; exiting."
}

#region Load Sepias-----------------------------------------------------------------------------------------------------------------

try {
    add-type -path "CPAs.dll" | out-null
    write-host "- CPAs.dll (CreateProcessAsUser) loaded into memory."
} catch {
    write-host "! ERROR: Unable to load in CPAs.dll (CreateProcessAsUser)."
    write-host "  WinGet must be run as the logged-in user; it cannot be used via the SYSTEM user."
    write-host "  (Reminder: CPAs.dll can only be loaded into a single PowerShell session at a time.)"
    write-host "  Operations cannot continue. Exiting."
    exit 1
}

#region Set Up CPAs Array & Directories---------------------------------------------------------------------------------------------

$arrCPAsBlock=@()
new-item "$env:PUBLIC\CentraStage" -ItemType Directory -Force | out-null #does nothing if it's already present
remove-item "$env:PUBLIC\CentraStage\WinGet-$varEpoch.txt" -force -ea 0

#region Check For WinGet, or, if Instructed, Install--------------------------------------------------------------------------------

$varCPASBlock=@'
cmd /c "where winget"
set-content "$env:PUBLIC\CentraStage\WinGet-CPAsTest.txt" -value $LASTEXITCODE -force
'@
$varWinGetCheck=[murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser("C:\Windows\System32\WindowsPowershell\v1.0\Powershell.exe", "-command $($varCPASBlock)", "C:\Windows\System32\WindowsPowershell\v1.0\", $false, -1)

#if the file's contents are "1", winget wasn't found................................................................................
if ("$env:PUBLIC\CentraStage\WinGet-CPAsTest.txt" | select-string '1') {
    if ($env:usrInstallWinGet -eq 'true') {
        write-host "- WinGet is not installed for this user. Attempting installation..."
        #from https://learn.microsoft.com/en-us/windows/package-manager/winget/#install-winget
        try {
            iwr -Uri $(($(irm "https://api.github.com/repos/microsoft/winget-cli/releases/latest").assets.browser_download_url | ? {$_.EndsWith(".msixbundle")}).split("/")[-1]) -OutFile "WinGet.msixbundle"
            iwr -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
            Add-AppxPackage "Microsoft.VCLibs.x64.14.00.Desktop.appx"
            Add-AppxPackage "WinGet.msixbundle"
        } catch {
            write-host "! ERROR: Unable to download WinGet for this user."
            write-host "  Please attempt to install WinGet manually for this user via remote takeover."
            doCleanup
            exit 1
        }

        write-host "- NOTICE: WinGet appears to have been installed successfully."
        write-host "  Please re-try this Component on this system to confirm. You may need to reboot."
        write-host "- Exiting..."
        exit
    } else {
        write-host "! ERROR: WinGet does not appear to be installed for this user."
        write-host "  As usrInstallWinGet is not set to 'true', the Component will exit."
        exit 1
    }
} else {
    write-host "- WinGet appears to be available and functioning on this device."
}

#region Process User Variables------------------------------------------------------------------------------------------------------

$arrInstall=@()
$arrUpdate=@()

("usrWGInstall","usrWGInstallSITE") | % {
    $name=$_
    $value=(gci env: | ? {$_.name -eq $name}).value
    if ($value.length -ge 2) {
        write-host "- [Install] Loaded IDs from variable $name`: $value"
        $value.split(',') | % {
            $arrInstall+=(Get-Culture).TextInfo.ToTitleCase($_) -replace " "
        }
    } else {
        $varEmpty++
    }
}

("usrWGUpdate","usrWGUpdateSITE") | % {
    $name=$_
    $value=(gci env: | ? {$_.name -eq $name}).value
    if ($value.length -ge 2) {
        write-host "- [Update]  Loaded IDs from variable $name`:  $value"
        $value.split(',') | % {
            $arrUpdate+=(Get-Culture).TextInfo.ToTitleCase($_) -replace " "
        }
    } else {
        $varEmpty++
    }
}

#if all four variables are empty, list winget apps..................................................................................
if ($varEmpty -ge 4) {
    write-host "- NOTICE: No IDs were stated as part of usrWGInstall, usrWGInstallSITE,"
    write-host "  usrWGUpdate, or usrWGUpdateSITE, meaning there is nothing to process."
    write-host "  Instead, a list of all WinGet-compatible software will be enumerated."
    write-host ": Expect many more applications in this list than were initially installed using WinGet."
    write-host "  The app's search function detects applications which can be updated using WinGet"
    write-host "  regardless of whether the application in question was originally installed that way."
    write-host ": Apps with no 'Available' column are up-to-date; Apps with data there can be updated."

    #CPAs command to list all winget-compatible apps
    $varCPASBlock="winget list --accept-source-agreements --disable-interactivity --ignore-warnings | out-file `"$env:PUBLIC\CentraStage\WinGet-$varEpoch.txt`""
    [murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser("C:\Windows\System32\WindowsPowershell\v1.0\Powershell.exe", "-command $varCPASBlock", "C:\Windows\System32\WindowsPowershell\v1.0\", $false, -1) | Out-Null

    #output output in a manner befitting outputted output
    $varGoodLine=(get-content "$env:PUBLIC\CentraStage\WinGet-$varEpoch.txt" | select-string '-----').Linenumber
    get-content "$env:PUBLIC\CentraStage\WinGet-$varEpoch.txt" | select -skip ($varGoodLine - 2) | % {
        #why does it tAKE THIS MUCH WORK TO REMOVE NON-WINGET APPS AAAAAAHHHHHH :: https://github.com/microsoft/winget-cli/issues/1155
	    $_ -replace "$(cdPnt 00D4)$(cdPnt 00C7)$(cdPnt 00AA)","$(cdPnt 2026)" -replace "$(cdPnt 252C)$(cdPnt 00AB)","$(cdPnt 00AE)" | select-string " Id ","---","winget" | ? {
            $_ -notmatch 'MSIX\\'
        } | ? {
            $_ -notmatch 'ARP\\'
        }
    }
    doCleanup
    exit
}

#de-dupe arrays.....................................................................................................................
$arrInstall=$arrInstall | select -Unique
$arrUpdate=$arrUpdate | select -Unique

showBarrier

#region Arbitrary Waiting Period----------------------------------------------------------------------------------------------------

if (($env:usrWaitThreshold).length -ge 1) {
    if ($env:usrWaitThreshold -eq 1) {$env:usrWaitThreshold=2}
    $varTime=Get-Random -Minimum 1 -Maximum $env:usrWaitThreshold
    $varTimeSecs=$varTime*60

    write-host ": Maximum waiting period:  $env:usrWaitThreshold minutes"
    write-host ": Period for this session: $varTime minutes"
    start-sleep -seconds $varTimeSecs
    write-host "- Wait time reached. Proceeding."
    showBarrier
}

#region Process Update Commands-----------------------------------------------------------------------------------------------------

if ($arrUpdate -contains "ALL") {
    write-host "- 'Update' array contains the command 'ALL'."
    write-host "  All applications detected by WinGet will be updated."
    
    #run winget with the tack-R command.............................................................................................
    $arrCPAsBlock+="winGet upgrade -r -h --accept-package-agreements --accept-source-agreements --include-unknown --disable-interactivity;`"`$lastexitcode`" | out-file `"$env:PUBLIC\CentraStage\WG_U-ALL-$varEpoch.txt`""
} else {
    $arrUpdate | % {
        $arrCPAsBlock+="winGet upgrade --id $_ -h --accept-package-agreements --accept-source-agreements --include-unknown --disable-interactivity;`"`$lastexitcode`" | out-file `"$env:PUBLIC\CentraStage\WG_U-$_-$varEpoch.txt`""
    }
}

#region Process Install Commands----------------------------------------------------------------------------------------------------

$arrInstall | % {
    $arrCPASBlock+="winGet install --id $_ -h --accept-package-agreements --accept-source-agreements --include-unknown --disable-interactivity;`"`$lastexitcode`" | out-file `"$env:PUBLIC\CentraStage\WG_I-$_-$varEpoch.txt`""
}

#region Actual WinGet CPAs Command--------------------------------------------------------------------------------------------------

$varCounter=1
$arrCPAsBlock | % {
    write-host "- Processing command [$varCounter/$($arrCPAsBlock.count)] :: $(($_ -split '-h')[0])"
    [murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser("C:\Windows\System32\WindowsPowershell\v1.0\Powershell.exe", "-command $($_)", "C:\Windows\System32\WindowsPowershell\v1.0\", $false, -1) | Out-Null
    $varCounter++
}

#region Read Log Files--------------------------------------------------------------------------------------------------------------

showBarrier
#i'd rather have had one single log file we appended to, but sepias absolutely refused to co-operate, so i did what i had to do
gci "$env:PUBLIC\CentraStage\WG_*.txt" | % {
    if ($_.Name -match 'WG_I') {
        checkError $(get-content $_.FullName) $(($_.name -split "-")[1]) "Install"
    } else {
        checkError $(get-content $_.FullName) $(($_.name -split "-")[1]) "Update"
    }
}

#region Error Reminder Text---------------------------------------------------------------------------------------------------------

if ($script:varError -eq 1) {
    write-host "  Master list of WinGet installation error codes:"
    write-host "  https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md"
    write-host `r
    write-host "  As a reminder, WinGet is not curated or maintained by Datto, inc. and Datto Support cannot assist"
    write-host "  with issues pertaining to bad installer scripts or issues contacting download locations."
    write-host "  In the event of an install failure, users are encouraged to attempt to run the WinGet install command"
    write-host "  locally to glean information which can then be used either to file an issue with the problematic"
    write-host "  package or to aid in adding the download location as stated by WinGet to local firewall allow-lists."
}

#region Closeout--------------------------------------------------------------------------------------------------------------------

doCleanup
showBarrier
write-host "- Operations completed @ $(get-date)."
exit $script:varError
