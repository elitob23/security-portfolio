# ip-auto-scan

A small desktop tool that checks an IP address against [AbuseIPDB](https://www.abuseipdb.com) and prints the reputation summary in a window. Type an address, press Enter, get a score. Built for triage, where the same question — *is this IP known bad?* — comes up dozens of times a day.

**Author:** Elias Tobin

[← Back to python-scripts](../README.md) · [← Back to portfolio home](../../../README.md)

## Contents

- [Purpose](#purpose)
- [How It Works](#how-it-works)
- [Usage](#usage)
- [API Key](#api-key)
- [Reading the Output](#reading-the-output)
- [Requirements](#requirements)
- [Files](#files)
- [Notes](#notes)
- [Related Projects](#related-projects)

## Purpose

Checking an IP during triage normally means switching to a browser, loading the AbuseIPDB site, pasting the address, and reading a page built for humans rather than for speed. Do that thirty times in a shift and the context switching costs more than the lookups.

This script exists to:

- Put a single-purpose lookup window next to the console, with no browser in the loop
- Return only the seven fields that matter for a triage decision, not a full web page
- Keep the API key out of the script file, so the tool can live in a public repo
- Refuse to send anything to a third party that is not a valid IP address

## How It Works

The window has two parts: an input bar across the top and a log pane below it.

```
┌────────────────────────────────────────┐
│ IP: [ 198.51.100.42        ]  [ Scan ] │
├────────────────────────────────────────┤
│ > scanning 198.51.100.42 ...           │
│ {                                      │
│     "IP": "198.51.100.42",             │
│     "Abuse Confidence Score": 100,     │
│     "Total Reports": 2847,             │
│     ...                                │
│ }                                      │
└────────────────────────────────────────┘
```

Each lookup goes through four steps:

1. **Validate.** The typed value is parsed with `ipaddress.ip_address()`. Anything that is not a literal IPv4 or IPv6 address is rejected here, in the window, before any network call happens. Hostnames are rejected too.
2. **Request.** A GET to `https://api.abuseipdb.com/api/v2/check` with the address and `maxAgeInDays=90`, so the score reflects the last quarter rather than an IP's entire history.
3. **Read the response.** AbuseIPDB reports bad keys, malformed input and exhausted quota in an `errors` array rather than by failing the request, so those are checked for and printed. Without that check they arrive as a result with every field empty, which reads like a clean IP.
4. **Print.** Seven fields are pulled out of the response and written to the log pane as indented JSON.

The request runs on a background thread, so the window stays responsive while it is in flight, and the Scan button is disabled until the result lands. Because Tkinter widgets may only be touched from the main thread, results are handed back to it through `text_widget.after()` rather than written directly.

**On input validation.** An earlier version of this script watched the clipboard and scanned whatever appeared there. That is convenient and quietly dangerous: everything copied during a shift — passwords, internal hostnames, ticket text — gets sent to a third-party API. Typed input with a validation gate removes that entirely. It also protects the API quota, which a clipboard loop burns through on text that was never an IP.

## Usage

```bash
python ipautoscan.py
```

Type an address and press Enter, or click Scan. Results stack up in the pane, so a set of addresses from one alert stays on screen together and can be compared.

Errors appear in the same pane as the results:

```
Error: 'evil.example.com' is not a valid IPv4 or IPv6 address.
Error 401: Authentication failed.
Error: HTTPSConnectionPool(host='api.abuseipdb.com', port=443): Read timed out.
```

## API Key

The script reads the key from the `ABUSEIPDB_API_KEY` environment variable:

```powershell
# Windows, current session only
$env:ABUSEIPDB_API_KEY = "your-key-here"
python ipautoscan.py

# Windows, persisted for your user account
[Environment]::SetEnvironmentVariable("ABUSEIPDB_API_KEY", "your-key-here", "User")
```

```bash
# Linux / macOS
export ABUSEIPDB_API_KEY="your-key-here"
python ipautoscan.py
```

If the variable is not set, the script falls back to the placeholder string `your_API_here` and every lookup returns a 401. Replacing that placeholder in the file works, but the key then travels with the file — set the environment variable instead.

Keys are free from [abuseipdb.com/account/api](https://www.abuseipdb.com/account/api). The free plan allows 1,000 checks per day; the current limit for your plan is shown on that page.

## Reading the Output

| Field | Meaning |
|---|---|
| `IP` | The address that was checked, echoed back by the API |
| `Abuse Confidence Score` | 0-100. AbuseIPDB's confidence that the address is malicious, weighted by reporter reputation — not a count of reports |
| `Total Reports` | Reports filed in the last 90 days |
| `Country` | Two-letter country code from the IP registration |
| `ISP` | The network that owns the address |
| `Is Whitelisted` | `true` for addresses AbuseIPDB considers trusted infrastructure, such as major DNS resolvers and search engine crawlers |
| `Last Reported At` | Timestamp of the most recent report, or `null` if never reported |

Read the score as a starting point, not a verdict. A score of 0 means nobody has reported the address, which is also true of every address an attacker has not used yet. A high score on a shared or residential address may reflect a different customer on that IP last month. `Total Reports` and `Last Reported At` give the score its context: 2,000 reports ending yesterday and 3 reports from 80 days ago are not the same finding.

## Requirements

**Python 3.10+** and one third-party package:

```bash
pip install -r requirements.txt
```

`tkinter` is used for the window. It ships with the python.org installers for Windows and macOS. On Debian and Ubuntu it is packaged separately:

```bash
sudo apt install python3-tk
```

An AbuseIPDB API key is required. See [API Key](#api-key).

## Files

| File | Purpose |
|---|---|
| [ipautoscan.py](ipautoscan.py) | The script |
| [requirements.txt](requirements.txt) | Dependencies and the API key requirement |
| [howitworks.txt](howitworks.txt) | Line-by-line walkthrough of the code in plain English |

## Notes

- The script is sanitized. It contains no API key, no internal addresses, and no environment-specific values. The IPs in this README are from [RFC 5737](https://datatracker.ietf.org/doc/html/rfc5737) documentation ranges.
- Every lookup tells AbuseIPDB that someone is interested in that address. Consider what that means before checking addresses belonging to your own organization.
- Nothing is written to disk. Results exist in the window until it is closed.
- Lookups are one at a time by design. Bulk checking is a different tool, and AbuseIPDB's own `/check-block` and CSV endpoints are better suited to it.
- The 90-day window is hardcoded in `scan_ip()`. Change `maxAgeInDays` if you need a longer or shorter history.

## Related Projects

- [Security Triage Playbook](../../security-triage-playbook): the triage process this lookup feeds into
- [CrowdStrike Query Language (CQL)](../../cql-queries): finding the traffic that makes an IP worth checking
- [SOAR Automation](../../SOAR-Automation): the same enrichment, automated into a workflow
- [python-scripts](../README.md): the rest of the Python tooling in this repo
