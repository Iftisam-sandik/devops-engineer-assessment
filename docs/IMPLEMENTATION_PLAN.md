# Requirements and dependency order

The five-page assessment PDF is the specification; the pasted request adds explicit verification, Bengali handover, and approval constraints. Optional PDF bonuses are deferred until mandatory work is verified.

1. Application, endpoint tests, environment configuration, logs, metrics, graceful shutdown.
2. Hardened image and local Compose; measure image size and scan it.
3. Health automation and deployment transaction; test failures and rollback locally.
4. Terraform state bootstrap, EC2/IAM/logging, environment inputs. Validate locally; AWS apply requires owner approval and temporary identity.
5. PR CI and main release workflow using the tested image/deployment transaction.
6. Kubernetes deployment, HPA, generated Secret; attempt actual local update/undo and availability sampling.
7. Six-service monitoring stack, provisioned dashboards, logs and metrics validation, alert tests, real screenshots.
8. Reproducible documentation, compliance evidence, review/CI fixes, publication to the assigned repository.

Dependencies: release deployment needs a published image, approved AWS target and GitHub OIDC role; Kubernetes needs a working container runtime and local cluster; dashboards need application traffic plus exporter/log ingestion. Static validation is never substituted for successful deployment.

Optional: Alertmanager/webhooks, Kubernetes monitoring, tracing, Helm, image signing/SBOM and Ansible. No external messages or webhook sends are authorized.
