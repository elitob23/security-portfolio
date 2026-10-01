#event_simpleName=FEMVulnerabilityMutation
| FEMVulnerabilityMutation.VulnerabilityInstance.Cve.Id="CVE-2026-69414"
| table([
  FEMVulnerabilityMutation.VulnerabilityInstance.HostInfo.Hostname,
  FEMVulnerabilityMutation.VulnerabilityInstance.HostInfo.LocalIP,
  FEMVulnerabilityMutation.VulnerabilityInstance.HostInfo.OU,
  FEMVulnerabilityMutation.VulnerabilityInstance.Cve.BaseScore,
  FEMVulnerabilityMutation.VulnerabilityInstance.Cve.ExploitStatus,
  FEMVulnerabilityMutation.VulnerabilityInstance.Status,
  FEMVulnerabilityMutation.VulnerabilityInstance.DwellDays
])