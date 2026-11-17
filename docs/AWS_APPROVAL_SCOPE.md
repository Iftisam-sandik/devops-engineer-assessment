# Proposed AWS verification scope — approval pending

Local `terraform init -backend=false`, formatting and validation are performed before requesting approval. No AWS resources have been created and no AWS identity is configured in this environment.

Proposed region: **ap-south-1 (Mumbai)**. Test **staging only** first. The production tfvars reuse the same code with a separate state key and longer log retention.

Resources to create: one dedicated VPC/subnet/internet gateway/route table; one restricted security group (no inbound by default); one t3.micro EC2 instance with an encrypted 8 GiB gp3 disk and required IMDSv2; one 7-day CloudWatch log group; one private immutable-tag ECR repository/lifecycle policy; one EC2 IAM role/profile; one GitHub OIDC deployment role scoped to this repository’s production environment and staging-tagged assessment instances; a GitHub OIDC provider only if the account does not already have one; one encrypted, versioned, public-blocked S3 state bucket with native lock files.

No existing resource or permission is to be changed. Temporary AWS SSO or an environment-managed temporary identity is required; never paste access keys into chat or source. The reviewer should inspect an authenticated Terraform plan before apply. The maximum proposed assessment-test budget is **US$5**; stop before exceeding it. A few hours should ordinarily cost far less, but AWS actual usage governs billing.

After approval and authenticated planning: apply the state bootstrap; migrate its local state into a separate key in the approved bucket; apply workload infrastructure; populate ECR through OIDC; record plan/apply, EC2 `/health`, CloudWatch logs, successful release and rollback evidence. Bootstrap requires a previously published readable image digest. If using a private ECR bootstrap image, create/populate that repository before the EC2 apply (documented targeted bootstrap step); never rely on a private GHCR package being anonymously readable.

Cleanup approval should cover **only resources created for this assessment**, including repository images and state object versions after evidence has been copied out. The state bucket is deliberately protected with `prevent_destroy`; remove that guard only for the approved dedicated bucket after all workload resources have been destroyed. Never delete a shared OIDC provider or an existing bucket. No cleanup has been executed.

Standing production estimate (730 hours; planning assumptions, verify current AWS pricing): EC2 t3.micro $10.00, public IPv4 $3.65, gp3 8 GiB $0.77, CloudWatch logs $1.00, ECR/S3 $0.25 ≈ **$16/month**, excluding taxes, substantial egress and CPU credit overages. No NAT gateway or load balancer is included. TLS and high availability would increase cost.
