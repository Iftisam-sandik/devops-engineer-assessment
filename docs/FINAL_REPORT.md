# Assessment verification report

Date: 17 November 2026. Repository: https://github.com/Iftisam-sandik/devops-engineer-assessment

**The assessment is not fully complete: AWS execution remains blocked.** Infrastructure code is implemented and validates, but there is no approved temporary AWS identity or provisioning approval. No AWS resources, IAM permissions or external notification routes have been created or changed. An actual isolated plan attempt failed with `No valid credential sources found`.

The application, Docker packaging, CI/release definitions, Terraform, Kubernetes, six-component observability stack, Linux automation, README and Bengali handover are implemented. Remaining work is tracked by requirement in [COMPLIANCE_MATRIX.md](COMPLIANCE_MATRIX.md). Mandatory cloud acceptance is not replaced by static validation or local rollback evidence.

## Executed verification

| Area | Actual evidence and result |
| --- | --- |
| Application | 19 endpoint/configuration/lifecycle tests; 100% line/function coverage, 98.79% statements, 96.36% branches. Generic errors and optional metrics bearer protection tested. |
| Docker | Real multi-stage build; UID 1000, read-only write rejection and SIGTERM exit 0 checked in a real container. Exact final size/identity recorded in `docker-runtime.json`. |
| Security scan | CRITICAL gate passed. A broader scan identified bundled npm findings; runtime packaging was changed to omit unused package managers. The final full scan reports zero CRITICAL, zero HIGH and one MEDIUM zlib finding (CVE-2026-4738, fixed in 1.4-r0). Severity counts and identity are in `trivy-summary.json`; the earlier scan is retained as before-hardening evidence. |
| PR CI | Real GitHub Actions checks for lint, coverage, Hadolint, ShellCheck, Terraform validation, health integration, promtool, image scan, kind, monitoring and scheduled timer. Per-run source and artifact digests are in `ci-provenance.json`. |
| Main release | Pending the main-branch execution; no successful registry publication is claimed yet. |
| Kubernetes | Actual kind deployment, rolling update, `kubectl rollout undo`, availability samples with no failed HTTP responses, two ready replicas and actual HPA CPU observations. |
| Monitoring | All six components run. Application, host and container metrics, Loki logs, file-provisioned dashboards, real AppDown firing/recovery and genuine screenshots are verified. The final verifier requires populated request/error/latency queries after recovery and logs from all seven Compose services. |
| Alerts | Four real promtool rule tests evaluate thresholds/pending durations using synthetic input series. A separate live app outage demonstrates firing/recovery. Other production incidents are not fabricated. |
| Linux automation | Actual healthy/warning/critical exits 0/1/2, JSON, all-filesystem listing, top five processes, invalid flags/help, human log and bounded rotation checks. The real systemd five-minute timer fired with exit 0. |
| Terraform | Both stacks initialized without remote backends and validated; provider hashes locked. Remote state, authenticated plan/apply, IAM effectiveness, EC2 bootstrap/health, CloudWatch delivery and destruction remain unverified. |
| Rollback transaction | Real local registry/containers: good release starts, wrong-port candidate fails, previous image/config is restored and health/version are verified. Invalid config is rejected before touching the running container. This is not EC2 evidence. |

## Evidence index

- [CI provenance](evidence/ci-provenance.json), [coverage](evidence/coverage-summary.json), [unit output](evidence/unit-tests.txt).
- [Final Docker runtime checks](evidence/docker-runtime.json), [build output](evidence/docker-build.txt), [full scan](evidence/trivy-full.json), [scan summary](evidence/trivy-summary.json), [earlier npm findings](evidence/trivy-before-runtime-hardening.json).
- [Kubernetes rollout/undo](evidence/kubernetes-rollout.txt), [HTTP availability samples](evidence/kubernetes-availability.txt), [HPA and pod metrics](evidence/kubernetes-hpa.txt), [resources](evidence/kubernetes-resources.txt).
- [Live monitoring results](evidence/monitoring-verification.json), [Loki query](evidence/loki-query.json), [alert tests](evidence/prometheus-alert-tests.txt), [running containers](evidence/monitoring-containers.txt).
- [Application screenshot](screenshots/application.png), [Host screenshot](screenshots/host.png), [Containers screenshot](screenshots/containers.png).
- [Health integration](evidence/health-script-tests.json), [actual timer journal](evidence/health-timer.txt), [local deployment/rollback](evidence/deployment-transaction.txt).
- [Terraform validation](evidence/terraform-validate.txt), [bootstrap validation](evidence/terraform-bootstrap-validate.txt), [actual unauthenticated plan failure](evidence/aws-plan-attempt.txt).

The monitoring screenshots were captured from a running Grafana UI using Chromium. They were not drawn, generated or edited to resemble results. GitHub artifact ZIP SHA-256 digests were checked against the returned metadata before retained files were copied into the repository. CI artifacts also remain available at their linked run until GitHub retention expires; committed evidence remains in Git history.

## Environment limitations and how they were handled

The managed coding environment uses rootless Docker with cgroup driver `none`. kind refuses cluster creation without systemd `Delegate=yes`; local cAdvisor lacks per-container limits. Actual failure output is retained in [kind-create.txt](evidence/kind-create.txt), and partial local monitoring is marked in [local-monitoring-verification.json](evidence/local-monitoring-verification.json). Neither is called a successful local Kubernetes/container-metrics test. A standard GitHub-hosted runner successfully executes the real cluster and complete monitoring checks instead.

The environment's TLS proxy initially prevented npm inside Docker, and its proxy settings intercepted internal monitoring service names. The final build accepts a temporary trusted CA secret without disabling verification. Monitoring appends only its local service names to existing proxy exclusions. Startup/read permissions and named-volume ownership were corrected and verified by rerunning the live stack.

Visual screenshot review caught an empty application request-rate panel after the outage test. Continuous real test traffic and explicit rate/quantile assertions now guard captures. The generated 404 traffic is documented; a 5xx production incident is not claimed.

## AWS work still required

The requested approval scope is [AWS_APPROVAL_SCOPE.md](AWS_APPROVAL_SCOPE.md). Approval and a temporary identity are both still required; elapsed time is not approval. Do not put credentials in chat or source.

After these are available: create the dedicated state bucket, migrate/initialize locked state, inspect an authenticated staging plan, apply the approved infrastructure, bootstrap a readable image, verify EC2 and CloudWatch, configure the repository-scoped OIDC deployment variables, run a main release and an actual failed-release rollback on EC2, preserve evidence, then clean up only approved assessment-created resources. S3 state and ECR deliberately prevent accidental cleanup; do not delete shared resources/providers.

The proposed test budget is US$5; the documented small standing production estimate is about US$16/month before tax/egress. No AWS charges have been intentionally incurred by this task. AWS deployment jobs remain disabled until `AWS_DEPLOY_ENABLED=true` is explicitly configured after approved setup.

## Submission and disclosure

The public repository, README, compliance matrix, genuine evidence and [beginner-friendly Bengali handover](../TECHNICAL_HANDOVER.md) are prepared for review. The repository must be submitted with the AWS gap disclosed; it does not meet the user's full definition of done while mandatory cloud verification is blocked.

OpenAI Codex assisted with implementation and documentation. Commands and CI actually ran. The applicant should review and reproduce the implementation and explain it personally; unaided authorship or cloud experience not supported by evidence is not claimed.
