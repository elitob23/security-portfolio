# w11-24h2

A CQL query that lists every Windows endpoint running build 26100, the build number for Windows 11 version 24H2, based on Falcon sensor OS version telemetry.

Query file: [`24h2.cql`](24h2.cql)

## Purpose

When a new Windows feature update rolls out, you need to know which machines already have it. This query gives that list using only data the Falcon sensor already collects, with no need for Intune, SCCM or another inventory tool.

Typical uses:

- Tracking progress of a 24H2 upgrade rollout
- Scoping impact when a bug, compatibility problem or vulnerability affects only 24H2
- Finding machines that upgraded outside the planned rollout
- Building a host list to target with a policy, script or host group

## How it works

The query takes the `OsVersionInfo` events that the Falcon sensor reports for each host. It keeps the Windows events with `BuildNumber` 26100 and groups them into one row per host.

For a line-by-line walkthrough, see [`howitworks.txt`](howitworks.txt).

## Output

| Field          | Description                                                  |
|----------------|--------------------------------------------------------------|
| `aid`          | Falcon agent ID                                              |
| `ComputerName` | Endpoint hostname                                            |
| `EventCount`   | Number of `OsVersionInfo` events from that host in the time range |

`EventCount` is how many times the host reported its OS version. It doesn't measure usage or risk. It mostly reflects how often the sensor started or reconnected.

## Usage

1. Open **Next-Gen SIEM → Advanced event search** in Falcon.
2. Paste in the contents of `24h2.cql`.
3. Set a time range when you run the search. The query doesn't set one. Use at least 7 days, and ideally 30. Hosts only send `OsVersionInfo` now and then, so a short window will miss machines that haven't reported recently.

To look for a different Windows release, change the `BuildNumber` value:

| Release                         | BuildNumber |
|---------------------------------|-------------|
| Windows 11 22H2                 | 22621       |
| Windows 11 23H2                 | 22631       |
| Windows 11 24H2                 | 26100       |
| Windows 11 25H2                 | 26200       |

## Limitations and tuning

- **Windows Server 2025 also uses build 26100.** Servers on Server 2025 show up in the results alongside Windows 11 24H2 workstations. To exclude them, filter on a field that tells workstations and servers apart (such as the product type or name) if your `OsVersionInfo` data includes one.
- **Hosts can appear more than once over time.** A host that upgraded to 24H2 during the time range shows up here, even though it was on an older build earlier in the window. A host that upgraded past 24H2 (for example to 25H2) during the window can also still appear, because its older 24H2 events are in range.
- **Offline hosts are missed.** A machine that didn't report `OsVersionInfo` during the time range won't appear, even if it runs 24H2.
- **Patch level isn't shown.** Every 24H2 cumulative update keeps build 26100, so this query can't tell a fully patched host from an unpatched one.
- **Result size.** `groupBy()` returns a limited number of rows by default. In a large fleet, add a higher `limit` to `groupBy()` so the list isn't cut off.

## Status

Tested
