# Security policy

## Supported versions

Security fixes are applied to the latest commit on `main`.

## Reporting a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/erxxc/verbatim/security/advisories/new). Do not open a public issue for suspected vulnerabilities and do not include sensitive text, credentials, or personal translation content in reports.

Include the affected macOS version, the application where the issue occurs, reproduction steps using non-sensitive sample text, and the expected security or privacy boundary. You can expect an acknowledgment within seven days.

## Privacy boundary

The native macOS helper uses Apple's on-device Translation framework and does not send translation content to this project or a project-operated server. Its Accessibility and Input Monitoring permissions are used to detect sentence endings and replace text in the focused field. The separate browser prototype uses MyMemory for phrases outside its bundled offline phrasebook; that network behavior is documented in the README.

