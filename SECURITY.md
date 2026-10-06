# Security policy

## Supported versions

Security fixes, when available, are intended for the current default branch and the latest published Bon release. This project is pre-release and has no formal support window or response-time commitment.

## Reporting a vulnerability

Please do not publish exploit details or sensitive data in a public issue. Use GitHub's private vulnerability reporting for this repository if the owner has enabled it. If that option is unavailable, contact the repository maintainer privately through their GitHub profile and include only the minimum detail needed to reproduce the issue.

Include the affected commit/version, environment, impact, and a safe reproduction outline. Do not include access tokens, private prompts, model files, or personal data. The maintainer will acknowledge reports when able; no SLA is offered.

Repository owners: enable **Private vulnerability reporting**, **Dependabot alerts**, **secret scanning/push protection** where available, and code scanning in GitHub repository settings. The workflow in `.github/workflows/codeql.yml` is a code-scanning starting point, not a substitute for enabling the GitHub feature.
