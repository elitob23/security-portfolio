// Name:        ClickFix investigation 3 - network connections
// Purpose:     Lists outbound IPv4 connections made by the flagged process
// Data source: base_sensor, NetworkConnectIP4
// Inputs:      ComputerName and TargetProcessId from the detection alert
// Status:      Production

#event_simpleName=NetworkConnectIP4
| ComputerName="REPLACE_WITH_COMPUTERNAME"
| ContextProcessId="REPLACE_WITH_TARGETPROCESSID"
| table([@timestamp, RemoteAddressIP4, RemotePort, Protocol])
