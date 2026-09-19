# python-scripts

A working collection of Python scripts I've written for security operations work: automating repetitive tasks, pulling and shaping data from security tools, and supporting investigations.

**Author:** Elias Tobin

[← Back to portfolio home](../../README.md)

## Contents

- [Purpose](#purpose)
- [Script Index](#script-index)
- [Structure](#structure)
- [Script File Format](#script-file-format)
- [Getting Started](#getting-started)
- [Notes](#notes)
- [Related Projects](#related-projects)

## Purpose

This folder exists to:

- Keep reusable scripts under version control instead of scattered across machines
- Document what each script does, what it needs, and how to run it safely
- Show the automation side of my security work alongside the PowerShell and CQL in the rest of this repo

## Script Index

| Script | Summary | Category | Status |
|---|---|---|---|
| [portscanner.py](port-scanner/portscanner.py) | Multithreaded TCP port scanner that lists open ports and their common service names. Standard library only. See [howitworks.txt](port-scanner/howitworks.txt) for a line-by-line walkthrough | Utilities | ✅ Completed |
| [passwordgenerator.py](password-generator/passwordgenerator.py) | Builds readable 15-16 character passwords for new user accounts and copies the result to the clipboard. Standard library only. See the [README](password-generator/README.md) for the format and strength notes | Automation | ✅ Completed |
| [ipautoscan.py](ip-auto-scan/ipautoscan.py) | Desktop lookup window that checks a typed IP address against the AbuseIPDB API and reports its abuse score, report count and owning network. Needs `requests` and an API key. See the [README](ip-auto-scan/README.md) for setup and [howitworks.txt](ip-auto-scan/howitworks.txt) for a line-by-line walkthrough | Incident Response | ✅ Completed |

**Categories:** Automation · Detection & Hunting · Incident Response · Vulnerability Management · Reporting · Utilities

**Status key:** 🚧 Draft = work in progress · 🧪 Tested = validated in a lab · ✅ Production = used in real work

## Structure

Each script lives in its own `.py` file, named in lowercase with hyphens, for example `parse-falcon-detections.py`.

If a script needs more than one file (helpers, sample data, config templates), it gets its own subfolder with its own README:

```
python-scripts/
├── README.md
├── requirements.txt          # shared dependencies (added with the first script that needs one)
├── single-file-script.py
└── multi-file-script/
    ├── README.md
    ├── main.py
    └── sample-config.example.yaml
```

## Script File Format

Every script starts with a docstring header so it can be understood without opening this README:

```python
"""
Name:         Short descriptive title
Purpose:      What problem this script solves
Inputs:       Files, API data, or arguments it expects
Outputs:      What it produces (report, CSV, console output, action taken)
Requirements: Python version, third-party packages, API scopes or permissions
Usage:        python script-name.py --example-arg value
Status:       Draft | Tested | Production
"""
```

## Getting Started

**Prerequisites:** Python 3.10+

```bash
# Clone the repo and move into this folder
git clone <repo-url>
cd security-portfolio/work-projects/python-scripts

# Create and activate a virtual environment
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Show a script's options
python script-name.py --help
```

Credentials and API keys are never hardcoded. Scripts that need them read from environment variables or a local config file that is excluded from version control.

## Notes

- All scripts are sanitized. No hostnames, usernames, IP addresses, domains, API keys, or other environment-specific identifiers are included. Placeholder values are used where an identifier would otherwise appear.
- Scripts that take action on systems (isolation, remediation, account changes) should be tested in a lab before production use.
- These scripts are provided as-is for reference. Review and adapt them to your own environment before running them.

## Related Projects

- [Critical Vulnerability Management](../vulnerability-management): PowerShell remediation scripts deployed through CrowdStrike RTR
- [Domain-Wide Password Policy Overhaul](../password-policy): PowerShell and GPO rollout
- [CrowdStrike Query Language (CQL)](../cql-queries): detection and hunting queries
- [SOAR Automation](../SOAR-Automation): security orchestration and automated response workflows
- [Security Triage Playbook](../security-triage-playbook): the triage process these tools support
