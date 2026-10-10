// Name:        ClickFix investigation 4 - DNS queries
// Purpose:     Lists domains resolved by the flagged process
// Data source: base_sensor, DnsRequest
// Inputs:      ComputerName and TargetProcessId from the detection alert
// Status:      Production

#event_simpleName=DnsRequest
| ComputerName="REPLACE_WITH_COMPUTERNAME"
| ContextProcessId="REPLACE_WITH_TARGETPROCESSID"
| table([@timestamp, DomainName])
