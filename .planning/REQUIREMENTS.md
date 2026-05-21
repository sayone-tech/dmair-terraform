# Requirements: dmair-terraform

**Defined:** 2026-05-20
**Core Value:** Live infra is sacred — `terraform plan` on every existing live stack must report "No changes" after every refactor commit. The dmair-backend staging slot is delivered on top of that invariant.

## v1 Requirements

### Bootstrap — State Backend

- [ ] **BOOTSTRAP-01**: `bootstrap/` Terraform stack exists that `terraform import`s the existing `dmair-terraform-prod` S3 bucket AND declares a new `dmair-terraform-locks` DynamoDB lock table in `us-west-2`. The state backend is self-describing IaC.
- [ ] **BOOTSTRAP-02**: Every existing backend.tf (`envs/strapi`, `envs/frontend/staging`, `envs/frontend/prod`) is wired with `dynamodb_table = "dmair-terraform-locks"`. Each stack is `terraform init -reconfigure`'d. Plans remain zero-change after the rewire.
- [ ] **BOOTSTRAP-03**: Concurrent `terraform apply` from two operators is prevented by the lock table (verified by attempting and observing the lock contention).

### Refactor — Folder Layout

- [ ] **REFACTOR-01**: The folder layout migrates from `envs/<x>` to `live/dmair/<component>/<env>`. Specifically: `envs/strapi` → `live/dmair/strapi/prod`, `envs/frontend/prod` → `live/dmair/frontend/prod`, `envs/frontend/staging` → `live/dmair/frontend/staging`. State keys at `strapi/`, `frontend/staging/`, `frontend/prod/` remain at their current paths in the bucket (folder rename only).
- [ ] **REFACTOR-02**: Every resource address that moves uses a `moved {}` block so that `terraform plan` on each migrated stack reports **"No changes"**. This is the hard exit criterion for the refactor — no exceptions.
- [ ] **REFACTOR-03**: `live/dmair/staging/` slot is reserved (directory exists with at minimum a placeholder README) for the dmair-backend staging deploy.

### Documentation

- [ ] **DOCS-01**: README updated to describe the new `live/<project>/<component>/<env>` layout, the `bootstrap/` stack, and the DynamoDB lock table. The legacy "company-website production stack" framing is removed — the docs reflect that this repo owns three live stacks (strapi CMS, frontend prod, frontend staging) plus the new backend staging slot.

### Staging — dmair-backend Slot

- [ ] **STAGING-01**: `live/dmair/backend/staging/` Terraform stack provisions the full staging AWS resource set per `dmair-backend/deployment/staging/STAGING-DEPLOYMENT.md` §10. Targets `api-staging.flydmair.com`. Required components:
  - **Networking:** VPC + 2 public subnets across 2 AZs + IGW + route tables (per STAGING-DEPLOYMENT.md §3.1)
  - **Compute:** EC2 `t4g.medium` (Ubuntu 24.04 LTS ARM64) + Elastic IP + EBS encryption at rest
  - **IAM:** EC2 instance role with: SSM Session Manager, ECR pull, Secrets Manager read, CloudWatch logs write
  - **Security groups:** EC2 (`80`/`443` from Internet, no SSH); RDS (`5432` from EC2 SG only)
  - **Database:** RDS PostgreSQL 16 + PostGIS extension, `db.t4g.micro`, Single-AZ, automated backups
  - **Container registry:** ECR repository for the dmair-backend image (ARM64)
  - **Secrets:** AWS Secrets Manager — 1 consolidated JSON secret for app config
  - **Logs:** CloudWatch log group `/dmair/staging`, 5-day retention
  - **Cost guard:** AWS Budgets monthly threshold + email notification for this staging stack
  - **Out of scope for this requirement:** EC2 user-data (docker-compose launcher), Caddy config, the dmair-backend image itself — those are dmair-backend ART-* requirements, not terraform.
- [ ] **STAGING-02**: A DNS A-record for `api-staging.flydmair.com` points at the staging backend's Elastic IP. An ACM/Let's Encrypt cert for that hostname is acquirable from the EC2 host.
- [ ] **STAGING-03**: A GitHub OIDC IAM role + tag/prefix-scoped IAM policy lets `dmair-backend` CI deploy into `live/dmair/staging/*` without being able to mutate existing `cms-*` / `frontend-*` resources in the shared `dmair` AWS account. Scoping is verified by an explicit deny-by-exclusion test (CI role attempts to read or modify a frontend resource and is rejected).

### CI/CD — Terraform Pipeline

- [ ] **CICD-01**: `.github/workflows/terraform.yml` runs `terraform fmt -check`, `terraform validate`, and `terraform plan` on every PR to `main` for each `live/*` stack and `bootstrap/`. On merge to `main`, a required-reviewer-gated `terraform apply` runs per stack via GitHub Environments (one environment per stack: `bootstrap`, `prod-strapi`, `prod-frontend`, `staging-frontend`, `staging-backend`). The pipeline assumes the per-repo GitHub OIDC role provisioned in STAGING-03 / a new OIDC-01.
- [ ] **CICD-02**: GitHub OIDC trust provider + per-repo per-stack IAM roles exist for `sayone-tech/dmair-terraform` (terraform pipeline) and the role names + ARNs are documented in a new `OIDC.md` runbook for operator handoff to `dmair-backend`.

## v2 Requirements

Deferred to future milestones — tracked but not in this roadmap.

### Production Slot

- **PROD-01**: `live/dmair/prod/backend/` production slot for dmair-backend (lifts from staging once staging proves out).

### Quality Tooling

- **QA-01**: `tflint` / `checkov` / `tfsec` integration with CI gate.
- **QA-02**: `terratest` harness for module-level smoke tests.
- **QA-03**: Automated drift detection (scheduled `terraform plan` reports).

### State-Key Cleanup

- **STATE-01**: Relocate state keys to match new folder layout (e.g. `strapi/terraform.tfstate` → `live/dmair/strapi/prod/terraform.tfstate`). Deferred — accepted as drift in v1.

## Out of Scope

| Feature | Reason |
|---------|--------|
| `us-east-1` region for any stack | EC2 `prevent_destroy = true` blocks a region migration; shared `us-west-2` is cheaper and simpler |
| Separate AWS account for dmair-backend | Single shared `dmair` account is existing reality; isolation deferred until concrete need arises |
| Migrating `staging.flydmair.com` to a different name | Backend gets `api-staging.flydmair.com` instead — touching live frontend DNS is unnecessary risk |
| Relocating state keys during the folder rename | Keep state keys at current paths to avoid per-stack `terraform state mv` migrations. Tracked as v2 STATE-01 |
| `terratest` / `checkov` / `tfsec` introduction | Out of this milestone. Quality gating is the zero-change-plan invariant. Tracked as v2 QA-* |
| Production deployment slot for dmair-backend | Staging only this milestone. Tracked as v2 PROD-01 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BOOTSTRAP-01 | Phase 1 | Pending |
| BOOTSTRAP-02 | Phase 1 | Pending |
| BOOTSTRAP-03 | Phase 1 | Pending |
| REFACTOR-01 | Phase 2 | Pending |
| REFACTOR-02 | Phase 2 | Pending |
| REFACTOR-03 | Phase 2 | Pending |
| DOCS-01 | Phase 2 | Pending |
| STAGING-01 | Phase 3 | Pending |
| STAGING-02 | Phase 3 | Pending |
| STAGING-03 | Phase 3 | Pending |
| CICD-01 | Phase 4 | Pending |
| CICD-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---
*Requirements defined: 2026-05-20*
*Last updated: 2026-05-20 after roadmap creation (traceability populated)*
