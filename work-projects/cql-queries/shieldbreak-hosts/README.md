# shieldbreak-hosts

A CQL query that lists every endpoint Falcon Exposure Management has flagged as vulnerable to CVE-2026-69414 ("ShieldBreak"), along with the host details and exposure context needed to prioritize remediation.

Query file: [`shieldbreak.cql`](shieldbreak.cql)

## Purpose

When a high-profile vulnerability drops, the first question is always *which of our machines are affected?* This query answers it from data Falcon already collects, with no need for a separate vulnerability scanner.

Typical uses:

- Building the initial list of affected hosts when the CVE is announced
- Tracking remediation progress as patches roll out
- Prioritizing hosts by exploit status and how long they've been exposed
- Routing work to the right teams using the host's OU

## How it works

The query reads `FEMVulnerabilityMutation` events, which Falcon Exposure Management emits when a vulnerability instance on a host is created or changes state. It keeps the events for CVE-2026-69414 and outputs them as a table of host and vulnerability fields.

To reuse it for a different vulnerability, change the `Cve.Id` value on the second line.

## Output

All fields are prefixed with `FEMVulnerabilityMutation.VulnerabilityInstance.` in the results.

| Field                    | Description                                               |
|--------------------------|-----------------------------------------------------------|
| `HostInfo.Hostname`      | Endpoint hostname                                         |
| `HostInfo.LocalIP`       | Local IP address of the endpoint                          |
| `HostInfo.OU`            | Active Directory organizational unit of the host          |
| `Cve.BaseScore`          | CVSS base score of the CVE                                |
| `Cve.ExploitStatus`      | Known exploitation level of the CVE                       |
| `Status`                 | State of the vulnerability on that host (for example open or closed) |
| `DwellDays`              | Number of days the vulnerability has been present on the host |

## Usage

1. Open **Next-Gen SIEM → Advanced event search** in Falcon.
2. Paste in the contents of `shieldbreak.cql`.
3. Set a time range when you run the search. The query doesn't set one. Use a window that reaches back to when the CVE was first published, so hosts flagged early still appear.

## Limitations and tuning

- **Hosts can appear more than once.** Each state change is a separate mutation event, so a host that went from open to closed (or was reopened) shows up on several rows. To get one row per host with its latest state, replace `table()` with `groupBy([FEMVulnerabilityMutation.VulnerabilityInstance.HostInfo.Hostname], function=tail(1))` or sort by `@timestamp` and deduplicate.
- **Closed instances are included.** The query doesn't filter on `Status`, so remediated hosts are listed alongside open ones. Add a `Status` filter to see only hosts that still need work.
- **Result size.** `table()` returns 200 rows by default. In a large fleet, add a higher `limit` so the list isn't cut off.
- **Detection depends on Exposure Management.** Hosts only appear once Falcon has published coverage for the CVE and assessed them. Hosts without the sensor, or offline during the time range, won't appear.

## Status

Completed