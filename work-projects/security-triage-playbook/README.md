# Security Triage & Incident Response Playbooks

A collection of highly practical, ground-up triage playbooks designed for Security Operations Center (SOC) analysts, IT technicians, and systems administrators. These playbooks provide actionable, structured, and fast-paced workflows to investigate, escalate, or safely close common security detections.

## Why These Playbooks?
Most security documentation is either too academic or buried in deep vendor manuals. These playbooks focus on **practical application**:
* **Action-Oriented:** Written for the analyst in the hot seat with a "First 3 Things I Check" methodology.
* **Noise-Reduction:** Built-in false positive patterns to help identify benign activity quickly.
* **Clear Boundaries:** Explicit escalation thresholds so you know exactly when to close a ticket or sound the alarm.

---

## Playbook Master Template

Every playbook in this repository follows a standardized, predictable format:

```text
DETECTION NAME:
[The unique identifier or alert classification]

WHAT IT MEANS:
[In plain English, what behavior or event triggered this alert?]

SEVERITY LEVEL:
[Low / Medium / High / Critical — typical default classification]

FIRST 3 THINGS I CHECK:
1. [Core telemetry investigation]
2. [Identity & endpoint correlation]
3. [Threat intelligence & reputation validation]

FALSE POSITIVE PATTERNS:
[Benign scenarios, expected admin behavior, or known safe noise]

ESCALATION THRESHOLD:
[When to safely close as benign vs. when to escalate and isolate immediately]

HOW TO CLOSE IT:
[Resolution steps, documentation requirements, and platform dispositions]

EXAMPLE SCENARIO:
[A sanitized, real-world scenario illustrating the playbook in action]
