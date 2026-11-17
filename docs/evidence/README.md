# Execution evidence

Committed files in this directory are command output or API responses from actual execution, or explicit failure reports. Tool timestamps retain their original time zone; UTC fields are named accordingly. No credentials or authorization headers are included.

CI uploads fresh coverage, image scan, Kubernetes rollout/availability/HPA, monitoring/query/screenshots, and five-minute timer artifacts for each execution. See `docs/COMPLIANCE_MATRIX.md` for acceptance status and the final report for run URLs.

`kind-create.txt` is the actual managed-environment failure (rootless Docker lacks systemd cgroup delegation). This file does not establish whether the separate GitHub-hosted kind job succeeds.

Prometheus rule tests use specified synthetic input series to test real rule evaluation. They do not represent a production outage. The monitoring verifier separately stops the real application and records actual AppDown firing and recovery.
