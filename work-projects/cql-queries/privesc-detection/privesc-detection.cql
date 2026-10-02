// Name:        Privilege escalation after remote logon
// Purpose:     Correlates a remote logon, a non-elevated shell run by the same user,
//              and an elevated shell running as a different user on the same host
// Data source: base_sensor, UserLogon + ProcessRollup2 (Windows)
// ATT&CK:      TA0004 Privilege Escalation, T1548 Abuse Elevation Control Mechanism
// Severity:    Medium
// FP notes:    Approved JIT domain admin elevations are the main source. Also software
//              that launches shells as SYSTEM or admin. Exclude by CommandLine, not parent
// Origin:      Adapted from a CrowdStrike Falcon NG-SIEM correlation rule template,
//              tuned and deployed to production
// Status:      Production

#repo="base_sensor" event_platform="Win"
| in(field=#event_simpleName, values=["UserLogon", "ProcessRollup2"])
| case {
    // Stage 1: network (3) or RDP (10) logon from a remote IPv4 address
    #event_simpleName="UserLogon" LogonType=/^(3|10)$/ RemoteAddressIP4=*
    | logonTime := @timestamp
    | remLogon := format("[conn] %s -> %s", field=[RemoteAddressIP4, LocalIP])
    | loggedUser := UserName
    | successLogon := "true";

    // Stage 2: non-elevated process (Low/Medium integrity) launched from a shell or Explorer,
    // outside Program Files
    #event_simpleName="ProcessRollup2" IntegrityLevel>0 IntegrityLevel<12288 ParentBaseFileName=/(cmd|powershell|explorer|pwsh|powershell_ise)\.exe$/i ParentBaseFileName!=/CSFalconService\.exe/i ImageFileName!=/(\(Program\ Files|Program\ Files\ \(x86\))\)(.*\.(exe|dll)$)/i
    // Tuning: add exclusions here as | CommandLine!=/benign_proc_regex/
    | lowPrivUser := UserName
    | lowPrivTime := @timestamp 
    | lowPrivProcess := ImageFileName
    | lowPrivCmdLine := CommandLine
    | lowPrivExec := "true";

    // Stage 3: elevated shell (High/System integrity) started by something other than a
    // normal shell launcher, running as a user account (not a machine account)
    #event_simpleName="ProcessRollup2" IntegrityLevel>=12288 IntegrityLevel<20480 ImageFileName=/.*\(cmd|powershell|pwsh|powershell_ise)\.exe$/i ParentBaseFileName!=/(explorer|cmd|powershell|CSFalconService|RuntimeBroker|svchost|SenseIR|WmiPrvSE)\.exe/i UserName!=/\$/ ParentBaseFileName=*
    // Tuning: exclude by CommandLine, not by parent. The parent is the program being abused,
    // so excluding it would also hide a real exploit of that program
    | highPrivUser := UserName 
    | highPrivTime := @timestamp 
    | highPrivProcess := ImageFileName
    | highPrivCmdLine := CommandLine
    | highParent := ParentBaseFileName
    | highPrivExec := "true";
}
// Keep only hosts that have all three stages
| selfJoinFilter(field=[aid],
    where=[
        { successLogon="true" },
        { lowPrivExec="true" },
        { highPrivExec="true" }
    ]
)
| logonTimef := formatTime("%Y/%m/%d %H:%M:%S", field=logonTime)
| lowPrivTimef := formatTime("%Y/%m/%d %H:%M:%S", field=lowPrivTime)
| highPrivTimef := formatTime("%Y/%m/%d %H:%M:%S", field=highPrivTime)
// Group each host's events into sessions that end after a 10-minute gap
| groupBy([aid], 
    function=[
    session(
        [
        collect([remLogon, loggedUser, logonTimef, lowPrivUser, lowPrivCmdLine, lowPrivTimef, highPrivUser, highPrivProcess, highPrivCmdLine, highPrivTimef, highParent], limit=5000),
        min(lowPrivTime, as="minLowPrivTime"),
        min(highPrivTime, as="minHighPrivTime"),
        min(logonTime, as="minLogonTime")
        ],
        maxpause=10m
    )
    ]
)
// An elevated shell exists, the logon user ran the non-elevated stage,
// and the elevated shell runs as a different user
| highParent=*
| test(loggedUser==lowPrivUser)
| test(highPrivUser!=lowPrivUser)
// Stages must happen in order: logon, non-elevated, elevated
| test(minLogonTime<minLowPrivTime)
| test(minLowPrivTime<minHighPrivTime)
// Drop sessions of one minute or less
| formatDuration(_duration, precision=3, as="sessionDuration")
| sessionDurationMin := _duration/(1000*60)
| sessionDurationMin>1
| drop([_duration, @timestamp])
