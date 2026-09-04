# Security

## Scope

VPS Gözcü is a local macOS application. Monitoring runs only while the app is open and uses the user's existing SSH configuration. The repository does not contain server credentials, production profiles, or a central telemetry service.

## Safe usage

- Keep SSH private keys, passwords, host names, health URLs, backup paths, certificates, and notarization credentials outside the repository.
- The local `servers.json` file is intentionally ignored by Git.
- Host key verification stays enabled; do not disable it to work around a connection error.
- Remote monitoring uses a fixed read-only probe. Maintenance commands are separate, backup-first, and require explicit confirmation.

## Reporting a vulnerability

Please open a private GitHub Security Advisory for vulnerabilities. Do not include private keys, passwords, IP addresses, hostnames, or production logs in a public issue.
