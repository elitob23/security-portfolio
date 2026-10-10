// Name:        ClickFix execution from a browser, Office or Explorer
// Purpose:     Flags shells and LOLBins launched by a user-facing parent process
//              (browser, Office, PDF reader, Explorer), with command-line patterns
//              typical of ClickFix copy-paste lures
// Data source: base_sensor, ProcessRollup2 (Windows)
// ATT&CK:      TA0002 Execution, T1204.004 User Execution: Malicious Copy and Paste,
//              T1059.001 PowerShell, T1218.005 Mshta, T1105 Ingress Tool Transfer
// Severity:    Medium
// FP notes:    Browser native messaging hosts, OneDrive, signed Windows DLLs via rundll32,
//              hardware vendor utilities. Exclusions are in the
//              NOT (...) block at the bottom. Exclude by CommandLine, not by parent
// Schedule:    Scheduled search, daily over the last 24 hours
// Status:      Production

#event_simpleName=ProcessRollup2 event_platform=Win
// Focus on user-initiated parent processes (browsers, Office, Explorer)
| in(ParentBaseFileName, values=["explorer.exe", "chrome.exe", "msedge.exe", "firefox.exe", "iexplore.exe", "WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE", "AcroRd32.exe", "Acrobat.exe"], ignoreCase=true)
// Suspicious child processes
| in(FileName, values=["powershell.exe", "pwsh.exe", "cmd.exe", "mshta.exe", "wscript.exe", "cscript.exe", "rundll32.exe", "certutil.exe"], ignoreCase=true)
// Label each event with the high-confidence ClickFix pattern it matches. The final branch
// is a catch-all, so events that match no pattern are kept with ClickFixPattern="None".
// To alert only on pattern matches, add | ClickFixPattern!="None" after this block
| case {
    // Pattern 1: Clipboard manipulation, alone or with execution/download or lure wording
    CommandLine=/(clip|Set-Clipboard|Get-Clipboard)/i
    | case {
        CommandLine=/(iex|invoke-expression|iwr|irm|downloadstring|frombase64string|certutil.*http)/i | ClickFixPattern := "Clipboard + execution";
        CommandLine=/(verification|captcha|human|robot|cloudflare|security.check)/i | ClickFixPattern := "Clipboard + lure wording";
        * | ClickFixPattern := "Clipboard";
      }
    ;
    // Pattern 2: Obfuscated execution (encoded commands, hidden windows)
    CommandLine=/(-e\s+[A-Za-z0-9+\/=]{20,}|-enc\s+[A-Za-z0-9+\/=]{20,}|-encodedcommand\s+[A-Za-z0-9+\/=]{20,})/i | ClickFixPattern := "Encoded command";
    CommandLine=/(-w\s+h|-windowstyle\s+hidden)/i CommandLine=/(iex|invoke-expression|downloadstring)/i | ClickFixPattern := "Hidden window + execution";
    // Pattern 3: Direct malicious URL execution
    CommandLine=/mshta.*https?:\/\//i | ClickFixPattern := "mshta URL";
    CommandLine=/certutil.*(urlcache|decode).*http/i | ClickFixPattern := "certutil download";
    // Pattern 4: Social engineering + web download
    CommandLine=/(verification|captcha|human|robot|cloudflare|security.check|press.any.key)/i
    | CommandLine=/(iwr|irm|curl.*http|wget|downloadstring)/i | ClickFixPattern := "Lure wording + download";
    * | ClickFixPattern := "None";
  }
// Exclusions for known legitimate patterns
| NOT (
    // Browser utility processes
    (ParentBaseFileName=/^(chrome|msedge)\.exe$/i AND CommandLine=/(--type=|--utility-sub-type=|--service-sandbox-type=)/i)
    // OneDrive operations
    OR CommandLine=/OneDrive.*FileCoAuth\.exe.*-Embedding/i
    OR CommandLine=/cmd\.exe.*\/[cq]\s+(del|rmdir)\s+\/[sq]\s+.*\\AppData\\Local\\Microsoft\\OneDrive\\/i
    // Microsoft signed DLL operations
    OR (FileName="rundll32.exe" AND CommandLine=/dfshim\.dll|shell32\.dll|printui\.dll|davclnt\.dll/i)
    // Windows sleep/hibernate operations
    OR (FileName="rundll32.exe" AND CommandLine=/powrprof\.dll,SetSuspendState/i)
    // Hardware vendor utilities
    OR CommandLine=/LogiLDA\.dll|DellCommandUpdate|HPSupportSolutionsFramework/i
    // CrowdStrike Falcon browser extension
    OR (FileName="cmd.exe" AND CommandLine=/CsFalconConnector\.exe.*chrome-extension:\/\//i)
    // Adobe Acrobat browser extension
    OR (FileName="cmd.exe" AND CommandLine=/WCChromeNativeMessagingHost\.exe.*(chrome-extension:\/\/|\\\\\.\\pipe\\chrome\.nativeMessaging)/i)
    // Microsoft BrowserCore
    OR (FileName="cmd.exe" AND CommandLine=/BrowserCore\.exe.*chrome-extension:\/\/.*\\\\\.\\pipe\\chrome\.nativeMessaging/i)
    // Google Drive for desktop
    OR (FileName="cmd.exe" AND CommandLine=/switchblade_host\.exe.*chrome-extension:\/\/.*\\\\\.\\pipe\\chrome\.nativeMessaging/i)
    // RMM agent installer (environment-specific, placeholder)
    OR (FileName="cmd.exe" AND CommandLine=/REPLACE_WITH_RMM_INSTALLER_NAME.*install\.(bat|cmd)/i)
    // Line-of-business application service scripts (environment-specific, placeholder)
    OR (FileName="cmd.exe" AND CommandLine=/REPLACE_WITH_APP_FOLDER.*\\(restart_service|service)\.(bat|cmd)/i)
    // Generic browser extension native messaging
    OR CommandLine=/NativeMessagingHost\.exe.*(chrome-extension:\/\/|moz-extension:\/\/|\\\\\.\\pipe\\(chrome|firefox)\.nativeMessaging)/i
  )
| table([@timestamp, ComputerName, UserName, ParentBaseFileName, FileName, ClickFixPattern, CommandLine, ParentProcessId, TargetProcessId, @id])
