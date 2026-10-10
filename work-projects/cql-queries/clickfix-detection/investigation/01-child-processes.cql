// Name:        ClickFix investigation 1 - child processes
// Purpose:     Shows what the flagged process launched. Always run this first.
//              TargetProcessId of each child can be fed into queries 3-5
// Data source: base_sensor, ProcessRollup2
// Inputs:      ComputerName and TargetProcessId from the detection alert
// Status:      Production

#event_simpleName=ProcessRollup2
| ComputerName="REPLACE_WITH_COMPUTERNAME"
| ParentProcessId="REPLACE_WITH_TARGETPROCESSID"
| table([@timestamp, FileName, CommandLine, TargetProcessId, SHA256HashData])
