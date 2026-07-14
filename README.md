# security-portfolio

Elias' Security Portfolio — security projects completed on the job, alongside independent projects built in my homelab.

<img width="500" height="500" alt="nxKX671" src="https://github.com/user-attachments/assets/aa85b826-0041-42b3-955b-77938cfe494f" />

## Professional Profile

**Target Focus:** Cybersecurity

**Core Competencies:** Identity and Access Management, Vulnerability Management, SIEM (CrowdStrike Falcon, Wazuh), Endpoint Detection & Response, Network Security, Threat Hunting and Intelligence, Scripting (PowerShell)

**Education** Diploma in IT System Administration (With Honors)

**Active Qualifications:** [CCNA](https://www.credly.com/badges/8d46b3aa-948c-4b5d-b7a3-601fb8a5f801/public_url), CompTIA Network+, CompTIA A+

**In Progress:** CompTIA CySA+

## About This Repo

This repo is split into two categories:

- **`work-projects/`** — Security projects completed in a production environment. Write-ups are sanitized, but reflect real scope and outcomes.
- **`homelab/`** — Independent projects built and run in my personal Proxmox homelab, including SIEM deployment, network segmentation, and purple-team projects.

Each project folder includes a full README covering the problem, approach, technical detail, and outcome.

General self-hosted infrastructure (Pi-hole, Jellyfin, etc.) isn't part of this portfolio — that lives in a separate [homelab-infra repo](#).

## Work Projects

| Project | Summary | Status |
|---|---|---|
| [Credential Compromise Containment](work-projects/credential-compromise-containment) | Contained a live credential compromise across 300+ endpoints, 5 locations, in under 10 minutes via CrowdStrike Falcon | ✅ Complete |
| [Domain-Wide Password Policy Overhaul](work-projects/password-policy) | Redesigned password policy (15-char minimum, NIST-aligned) and rolled out via PowerShell to 300+ accounts | ✅ Complete |
| [JIT Access Model](work-projects/jit-access-model) | Deployed a just-in-time access model in CrowdStrike Falcon | ✅ Complete |
| [Security Triage Playbook](work-projects/security-triage-playbook) | Built the triage playbook my workflow runs on | ✅ Complete |
| [SOAR Compromised-Credential Workflow](work-projects/soar-compromised-credential-workflow) | Falcon Fusion SOAR detection-to-ticket automation | 🔄 In Progress |
| [Conditional Access / Zero Trust Baseline](work-projects/conditional-access-zero-trust-baseline) | Entra ID Conditional Access policy review and hardening | 🔄 In Progress |
| [FQL Threat Hunting Library](work-projects/fql-threat-hunting-library) | Falcon FQL hunting queries mapped to MITRE ATT&CK | 📋 Planned |
| [ASR Rules Rollout via Intune](work-projects/asr-rules-rollout-intune) | Attack Surface Reduction rules deployment and tuning | 📋 Planned |
| [Falcon Spotlight Patch Prioritization](work-projects/falcon-spotlight-patch-prioritization) | Risk-based vulnerability remediation workflow | 📋 Planned |

## Homelab

| Project | Summary | Status |
|---|---|---|
| [VLAN Segmentation](homelab/vlan-segmentation-project) | Six-VLAN network segmentation design | ✅ Complete |
| [Wazuh SIEM Deployment](homelab/wazuh-siem-deployment) | Single-node Wazuh deployment on Proxmox | 🔄 In Progress |
| [GOAD Purple Team Loop](homelab/goad-purple-team-loop) | GOAD attacks + Atomic Red Team, detected and analyzed in Wazuh | 📋 Planned |
| [SIEM Dashboard](homelab/siem-dashboard) | Log correlation, alerting, and MITRE ATT&CK-mapped playbooks | 📋 Planned |
| [Network Traffic Analyzer](homelab/network-traffic-analyzer) | Packet capture and traffic analysis tool | 📋 Planned |
| [Docker Security Audit](homelab/docker-security-audit) | Security auditing tool for containerized environments | 📋 Planned |
| [API Security Scanner](homelab/api-security-scanner) | Automated API vulnerability scanning | 📋 Planned |
| [Simple Vulnerability Scanner](homelab/simple-vulnerability-scanner) | Lightweight vulnerability scanning tool | 📋 Planned |

## Tech Stack

## Tech Stack

**SIEM & Detection:** CrowdStrike Falcon (EDR) · Wazuh · MITRE ATT&CK

**Identity & Access Management:** Microsoft Entra ID · Conditional Access · Zero Trust

**Network Security:** FortiGate · Aruba · VLANs · Routing & Switching · OPNsense

**Endpoint & Vulnerability Management:** Microsoft Intune · CrowdStrike Falcon (EDR) · PowerShell

**Email Security:** Proofpoint, Egress

**Automation & Scripting:** PowerShell

**Infrastructure & Virtualization:** Proxmox · Docker · VMWare Esxi

**Frameworks & Standards:** NIST SP 800-53 · SOC 2 TYPE 2 · MITRE ATT&CK

**Currently Building:** Python · Linux Hardening · Splunk

## License

MIT — see [LICENSE](LICENSE)
