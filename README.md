# security-portfolio

Elias' Security Portfolio - security projects completed on the job, alongside independent projects built in my homelab.

<img width="500" height="500" alt="nxKX671" src="https://github.com/user-attachments/assets/aa85b826-0041-42b3-955b-77938cfe494f" />

## Professional Profile

**Target Focus:** Cybersecurity / Vulnerability Management / Network Security / Detection Engineering

**Core Competencies:** Identity and Access Management, Vulnerability Management, SIEM (CrowdStrike Falcon, Wazuh), Endpoint Detection & Response, Network Security, Threat Hunting and Intelligence, Scripting (PowerShell)

**Education** Diploma in IT System Administration (With Honors)

**Active Qualifications:** [CCNA](https://www.credly.com/badges/8d46b3aa-948c-4b5d-b7a3-601fb8a5f801/public_url), CompTIA Network+, CompTIA A+

**In Progress:** CompTIA CySA+

## About This Repo

This repo is split into two categories:

- **`work-projects/`** - Security projects completed in a production environment. Write-ups are sanitized, but reflect real scope and outcomes.
- **`homelab/`** - Independent projects built and run in my personal Proxmox homelab.

Each project folder includes a full README covering the problem, approach, technical detail, and outcome.

## Work Projects

| Project | Summary | Status |
|---|---|---|
| [Critical Vulnerability Management](work-projects/vulnerability-management) | Remediated known Critical CVE's affecting Microsoft Teams, Zoom, and outdated .NET Frameworks | ✅ Complete |
| [Credential Compromise Containment](work-projects/credential-compromise-containment) | Contained a live credential compromise across 300+ endpoints, 5 locations, in under 10 minutes via CrowdStrike Falcon | ✅ Complete |
| [Domain-Wide Password Policy Overhaul](work-projects/password-policy) | Redesigned password policy (15-char minimum) and rolled out via PowerShell & GPO to 300+ accounts | ✅ Complete |
| [JIT Access Model](work-projects/jit-access-model) | Deployed a just-in-time access model in CrowdStrike Falcon | ✅ Complete |
| [Security Triage Playbook](work-projects/security-triage-playbook) | Built the triage playbook my workflow runs on | ✅ Complete |
| [Fortinet FortiGate 60F Firewall Replacement](work-projects/firewall-replacement) | Replaced a critical firewall in an enterprise setting | ✅ Complete |
| [SOAR Compromised-Credential Workflow](work-projects/soar-compromised-credential-workflow) | Falcon Fusion SOAR detection-to-ticket automation | 🔄 In Progress |

## Homelab

| Project | Summary | Status |
|---|---|---|
| [VLAN Segmentation](homelab/vlan-segmentation-project) | Six-VLAN network segmentation design | 🔄 In Progress |
| [Wazuh SIEM Deployment + OpenVAS](homelab/wazuh-siem-deployment) | Wazuh deployment on Ubuntu Server + OpenVAS Vulnerability Scanner | 🔄 In Progress |

## Tech Stack

**SIEM & Detection:** CrowdStrike Falcon (EDR) · Wazuh · MITRE ATT&CK

**Identity & Access Management:** Microsoft Entra ID · Conditional Access · Zero Trust

**Network Security:** FortiGate · Aruba · VLANs · Routing & Switching · OPNsense

**Endpoint & Vulnerability Management:** Microsoft Intune · CrowdStrike Falcon (EDR) · PowerShell

**Email Security:** Proofpoint

**Automation & Scripting:** PowerShell

**Infrastructure & Virtualization:** Proxmox · Docker · VMWare Esxi

## Contact
LinkedIn: [Elias Tobin](https://ca.linkedin.com/in/eliastobin)
Email: elitob23@gmail.com

## License

MIT — see [LICENSE](LICENSE)
