# Requirement compliance matrix

Source: all five PDF pages, plus the user’s pasted implementation request. PASS requires executed acceptance evidence. BLOCKED identifies a missing external permission or capability; NOT TESTED is pending.

| ID | Requirement | Implementation | Validation performed | Actual result | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 1.1 | Exact GET / response and application version | Pending | None yet | Pending | — | NOT TESTED |
| 1.2 | GET /health liveness/readiness | Pending | None yet | Pending | — | NOT TESTED |
| 1.3 | Prometheus requests, errors, latency histogram | Pending | None yet | Pending | — | NOT TESTED |
| 1.4 | Environment port, level, environment configuration | Pending | None yet | Pending | — | NOT TESTED |
| 1.5 | JSON stdout logs and graceful SIGTERM | Pending | None yet | Pending | — | NOT TESTED |
| 1.6 | Endpoint unit tests | Pending | None yet | Pending | — | NOT TESTED |
| 1.7 | Multi-stage minimal pinned Docker image; measured size | Pending | None yet | Pending | — | NOT TESTED |
| 1.8 | Non-root, HEALTHCHECK, OCI labels, dockerignore | Pending | None yet | Pending | — | NOT TESTED |
| 1.9 | Compose port 8080, health, restart, CPU/memory limits | Pending | None yet | Pending | — | NOT TESTED |
| 2.1 | PR lint, tests and coverage report | Pending | None yet | Pending | — | NOT TESTED |
| 2.2 | Hadolint and ShellCheck gates | Pending | None yet | Pending | — | NOT TESTED |
| 2.3 | PR image build and CRITICAL vulnerability gate | Pending | None yet | Pending | — | NOT TESTED |
| 2.4 | Main amd64/arm64 build and layer cache | Pending | None yet | Pending | — | NOT TESTED |
| 2.5 | Git SHA and semantic version image tags | Pending | None yet | Pending | — | NOT TESTED |
| 2.6 | Authenticated registry publication without hardcoded secrets | Pending | None yet | Pending | — | NOT TESTED |
| 2.7 | Automatic EC2 deploy, /health smoke, previous-image rollback | Pending | None yet | Pending | — | NOT TESTED |
| 2.8 | Document secrets/variables and verify actual workflow runs | Pending | None yet | Pending | — | NOT TESTED |
| 3.1 | EC2 in VPC and restricted security group | Pending | None yet | Pending | — | NOT TESTED |
| 3.2 | Least-privilege IAM instance profile; no access keys | Pending | None yet | Pending | — | NOT TESTED |
| 3.3 | Bootstrap Docker and application container | Pending | None yet | Pending | — | NOT TESTED |
| 3.4 | CloudWatch Logs with explicit retention | Pending | None yet | Pending | — | NOT TESTED |
| 3.5 | S3 remote state and state locking | Pending | None yet | Pending | — | NOT TESTED |
| 3.6 | Parameterized staging and production | Pending | None yet | Pending | — | NOT TESTED |
| 3.7 | Terraform init/validate/plan/apply evidence and cleanup | Pending | None yet | Pending | — | NOT TESTED |
| 4.1 | Actual local cluster deployment | Pending | None yet | Pending | — | NOT TESTED |
| 4.2 | Two replicas, rolling update, health probes | Pending | None yet | Pending | — | NOT TESTED |
| 4.3 | CPU/memory requests and limits | Pending | None yet | Pending | — | NOT TESTED |
| 4.4 | Service and Ingress or documented port-forward | Pending | None yet | Pending | — | NOT TESTED |
| 4.5 | ConfigMap and uncommitted generated Secret | Pending | None yet | Pending | — | NOT TESTED |
| 4.6 | Non-root and read-only filesystem security context | Pending | None yet | Pending | — | NOT TESTED |
| 4.7 | CPU HPA | Pending | None yet | Pending | — | NOT TESTED |
| 4.8 | Zero-downtime update with commands/output | Pending | None yet | Pending | — | NOT TESTED |
| 4.9 | kubectl rollout undo with commands/output | Pending | None yet | Pending | — | NOT TESTED |
| 4.10 | Production EKS differences | Pending | None yet | Pending | — | NOT TESTED |
| 5.1 | All six mandatory monitoring components run | Pending | None yet | Pending | — | NOT TESTED |
| 5.2 | Prometheus scrapes app, Node Exporter, cAdvisor | Pending | None yet | Pending | — | NOT TESTED |
| 5.3 | Explicit Prometheus retention | Pending | None yet | Pending | — | NOT TESTED |
| 5.4 | Alloy Docker discovery and all-container log collection | Pending | None yet | Pending | — | NOT TESTED |
| 5.5 | JSON parsing and bounded labels/filters | Pending | None yet | Pending | — | NOT TESTED |
| 5.6 | Explicit Loki retention | Pending | None yet | Pending | — | NOT TESTED |
| 5.7 | Provisioned Prometheus/Loki data sources | Pending | None yet | Pending | — | NOT TESTED |
| 5.8 | Application dashboard rate/errors/p50/p95/p99 | Pending | None yet | Pending | — | NOT TESTED |
| 5.9 | Host dashboard CPU/memory/disk/network | Pending | None yet | Pending | — | NOT TESTED |
| 5.10 | Container dashboard CPU/memory/limit ratio | Pending | None yet | Pending | — | NOT TESTED |
| 5.11 | Related Loki logs panel | Pending | None yet | Pending | — | NOT TESTED |
| 5.12 | Four alerts with thresholds and for durations | Pending | None yet | Pending | — | NOT TESTED |
| 5.13 | Grafana credentials from environment/secret | Pending | None yet | Pending | — | NOT TESTED |
| 5.14 | Only Grafana host-exposed; internal monitoring network | Pending | None yet | Pending | — | NOT TESTED |
| 5.15 | Pinned monitoring images and documented host privileges | Pending | None yet | Pending | — | NOT TESTED |
| 5.16 | Genuine screenshots of all three dashboards | Pending | None yet | Pending | — | NOT TESTED |
| 5.17 | Actual metrics/log/dashboard/alert validation | Pending | None yet | Pending | — | NOT TESTED |
| 5.18 | Error-spike investigation walkthrough | Pending | None yet | Pending | — | NOT TESTED |
| 6.1 | CPU/memory/all-mounted-disks/load/top5 processes | Pending | None yet | Pending | — | NOT TESTED |
| 6.2 | Timestamped health_log.txt and --json | Pending | None yet | Pending | — | NOT TESTED |
| 6.3 | Configurable thresholds and WARNING output | Pending | None yet | Pending | — | NOT TESTED |
| 6.4 | Exit codes 0 healthy, 1 warning, 2 critical | Pending | None yet | Pending | — | NOT TESTED |
| 6.5 | Bounded log rotation | Pending | None yet | Pending | — | NOT TESTED |
| 6.6 | Strict Bash, clean ShellCheck, --help | Pending | None yet | Pending | — | NOT TESTED |
| 6.7 | Five-minute schedule and execution verification | Pending | None yet | Pending | — | NOT TESTED |
| 6.8 | Normal/threshold/JSON/exit validation | Pending | None yet | Pending | — | NOT TESTED |
| 7.1 | Prerequisites and reproducible app/monitoring startup | Pending | None yet | Pending | — | NOT TESTED |
| 7.2 | Tests/script/Terraform/Kubernetes instructions | Pending | None yet | Pending | — | NOT TESTED |
| 7.3 | Delivery, EC2, Kubernetes, metrics/logs architecture diagram | Pending | None yet | Pending | — | NOT TESTED |
| 7.4 | Design Decisions and trade-offs | Pending | None yet | Pending | — | NOT TESTED |
| 7.5 | Deployment & Rollback Strategy | Pending | None yet | Pending | — | NOT TESTED |
| 7.6 | Security Considerations | Pending | None yet | Pending | — | NOT TESTED |
| 7.7 | Rough monthly AWS cost estimate | Pending | None yet | Pending | — | NOT TESTED |
| 7.8 | What I would improve with more time | Pending | None yet | Pending | — | NOT TESTED |
| 7.9 | Accurate AI usage note | Pending | None yet | Pending | — | NOT TESTED |
| User.1 | Beginner-friendly Bengali TECHNICAL_HANDOVER.md | Pending | None yet | Pending | — | NOT TESTED |
| User.2 | Small logical commits and feature PR | Pending | None yet | Pending | — | NOT TESTED |
| User.3 | Final evidence/report with honest blockers | Pending | None yet | Pending | — | NOT TESTED |

## Optional PDF bonuses

Deferred: Alertmanager/webhooks, monitoring in Kubernetes, tracing, Helm, signing/SBOM and Ansible. Mandatory requirements take priority.
