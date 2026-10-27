# Security Policy

## Reporting a vulnerability

Please do not open a public issue for security problems. Report them privately
through [GitHub private vulnerability reporting](https://github.com/y-sera/audio-app/security/advisories/new).

## CI/CD

- Workflows run only on manual dispatch (`workflow_dispatch`), which requires write
  access to this repository. Pull requests from forks do not trigger any workflow,
  and `pull_request_target` is not used.
- The default `GITHUB_TOKEN` is read-only; jobs request only the permissions they need,
  and only the release job may write packages.
- Only GitHub-owned actions and an allow-list of third-party actions may run, and every
  action must be pinned to a full commit SHA.
- No self-hosted runners are used.
