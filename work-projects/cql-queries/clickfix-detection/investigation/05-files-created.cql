// Name:        ClickFix investigation 5 - files created
// Purpose:     Lists scripts, executables and documents written by the flagged process
// Data source: base_sensor, NewScriptWritten + PeFileWritten + DocumentFileWritten
// Inputs:      ComputerName and TargetProcessId from the detection alert
// Status:      Production

#event_simpleName=/(NewScriptWritten|PeFileWritten|DocumentFileWritten)/
| ComputerName="REPLACE_WITH_COMPUTERNAME"
| ContextProcessId="REPLACE_WITH_TARGETPROCESSID"
| table([@timestamp, TargetFileName, SHA256HashData])
