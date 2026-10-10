// Name:        ClickFix investigation 2 - process timeline
// Purpose:     Shows every process on the host from 5 minutes before to 5 minutes
//              after the alert, to see what the user was doing
// Data source: base_sensor, ProcessRollup2
// Inputs:      ComputerName and @timestamp (epoch milliseconds) from the detection alert.
//              The search time range must include the alert time
// Status:      Production

#event_simpleName=ProcessRollup2
| ComputerName="REPLACE_WITH_COMPUTERNAME"
| test(@timestamp >= REPLACE_WITH_TIMESTAMP - 300000)
| test(@timestamp <= REPLACE_WITH_TIMESTAMP + 300000)
| table([@timestamp, ParentBaseFileName, FileName, CommandLine])
| sort(@timestamp)
