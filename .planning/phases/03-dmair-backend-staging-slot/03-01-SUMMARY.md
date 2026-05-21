---
phase: 03-dmair-backend-staging-slot
plan: 01
status: code-only-complete
---

# Plan 03-01 Summary — Staging backend stack HCL

## Status

**code-only-complete.** 13 `.tf` files for `live/dmair/staging/backend/`, matching `DMAir/dmair-backend/deployment/staging/STAGING-DEPLOYMENT.md` §10 field-for-field with three repo-convention substitutions. `terraform fmt -check` clean. `terraform init` / `apply` deferred to DevOps.

## Substitutions vs. the dmair-backend spec

| Spec says | Phase 3 uses | Why |
|---|---|---|
| `dynamodb_table = "dmair-terraform-locks"` | `use_lockfile = true` | Phase 1 quick-task 260520-ntp dropped DynamoDB locking in favor of S3-native `use_lockfile`. |
| `required_version = ">= 1.6"` | `required_version = "~> 1.15"` | Repo-wide convention; matches the rest of the stacks post-Phase 1. |
| `aws ~> 5.0` | `aws = "5.91.0"` | Hard pin; matches every other workspace. |

## Files (commit `2d96d8e` _(approx — fill from `git log`)_)

| File | Purpose |
|---|---|
| `backend.tf` | S3 backend at key `staging/backend/terraform.tfstate`; `use_lockfile = true`. |
| `providers.tf` | Terraform `~> 1.15`; `hashicorp/aws = "5.91.0"`; `default_tags` `{Project=dmair, Environment=staging, Component=backend, ManagedBy=terraform}`. |
| `variables.tf` | 22 inputs; 4 sensitive (db_password / jwt_secret_key / mail_password / admin_bootstrap_password) required via TF_VAR_* or `staging.auto.tfvars`. |
| `vpc.tf` | `10.0.0.0/16`, IGW, 2 public subnets across 2 AZs, public route table. Dedicated to dmair-staging — never shared. |
| `security_groups.tf` | EC2 SG (80/443 in from `web_ingress_cidrs`, no SSH); RDS SG (5432 from EC2 SG only). |
| `rds.tf` | PostgreSQL 16, `db.t4g.micro`, gp3 20 GB → autoscale to 100 GB, Single-AZ, encrypted, `publicly_accessible=false`, 7-day backups, `skip_final_snapshot=true`, `deletion_protection=false`. PostGIS extension installed by Flyway V6 at app start; no Terraform step. |
| `secrets.tf` | Single consolidated `dmair/staging/app` JSON secret with 4 keys. |
| `ecr.tf` | `dmair-backend` repo, scan-on-push, MUTABLE tags. Lifecycle: keep last 30 tagged, expire untagged after 14 days. |
| `cloudwatch.tf` | `/dmair/staging` log group, 5-day retention. |
| `iam.tf` | EC2 instance role + policies (ECR read, Secrets read, Logs write) + instance profile + AWS-managed `AmazonSSMManagedInstanceCore` attachment. |
| `ec2.tf` | `t4g.medium`, Ubuntu 24.04 LTS ARM64 from Canonical SSM param, IMDSv2-only, 30 GB gp3 encrypted root, `user_data = templatefile("./user-data.sh", {...})`, `ignore_changes = [ami]`. Companion EIP with `prevent_destroy = true`. |
| `budget.tf` | Monthly $60 ACTUAL cap (var-driven), 80% threshold email to `ops@flydmair.com` (var-driven). Filtered to `user:Project$dmair` + `user:Environment$staging` tags. |
| `oidc.tf` | GitHub OIDC identity provider (account-wide) + `dmair-backend-staging-deploy` IAM role. Trust policy restricts `sub` claim to `repo:sayone-tech/dmair-backend:ref:refs/heads/staging` + `:environment:staging`. Scoped permission policy (no wildcards) — STAGING-03 deny-by-exclusion. |
| `outputs.tf` | EIP, EC2 instance ID, SSM-session command, RDS endpoint, ECR URL, secret ARN, log group, OIDC role ARN, OIDC provider ARN. |

## DevOps blockers (must resolve before apply)

1. **Provide the four sensitive vars** via `staging.auto.tfvars` (gitignored — see `staging.auto.tfvars.example`) or `TF_VAR_*` in CI. `terraform plan` won't run without them.
2. **First-image chicken/egg:** the EC2 systemd unit fails its first start because the dmair-backend ECR repo has no image yet. Expected. Operator pushes the first ARM64 image then re-runs `sudo systemctl restart dmair-staging.service` via SSM.
3. **DNS at GoDaddy:** terraform output `elastic_ip` → operator creates `A api-staging.flydmair.com → <ip>` in the GoDaddy DNS panel **before** Caddy attempts ACME issuance. Without DNS, Caddy can't get a Let's Encrypt cert and the app is unreachable.
4. **§8.1(b) AdminBootstrapRunner blocker** from the spec — the create-or-activate admin bootstrap mode is not yet implemented in dmair-backend. Phase 3 ships the IaC; the admin bootstrap is the dmair-backend repo's responsibility.

## Hard invariant maintained

Nothing in this stack touches any pre-existing resource. The new VPC is independent of everything else in the account. Live infra (Strapi CMS, frontend prod/staging) plans clean throughout — no AWS-side action by Phase 3 code.

## Key files (created)

- `live/dmair/staging/backend/backend.tf`, `providers.tf`, `variables.tf`
- `live/dmair/staging/backend/vpc.tf`, `security_groups.tf`
- `live/dmair/staging/backend/rds.tf`, `secrets.tf`, `ecr.tf`, `cloudwatch.tf`, `iam.tf`
- `live/dmair/staging/backend/ec2.tf`, `budget.tf`, `oidc.tf`, `outputs.tf`
