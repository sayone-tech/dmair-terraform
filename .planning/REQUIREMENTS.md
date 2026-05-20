# Requirements: dmair-terraform

**Defined:** 2026-05-20
**Core Value:** Live infra is sacred — `terraform plan` on every existing live stack must report "No changes" after every refactor commit. The dmair-backend staging slot is delivered on top of that invariant.

## v1 Requirements

### Bootstrap — State Backend

- [ ] **BOOTSTRAP-01**: `bootstrap/` Terraform stack exists that `terraform import`s the existing `dmair-terraform-prod` S3 bucket AND declares a new `dmair-terraform-locks` DynamoDB lock table in `us-west-2`. The state backend is self-describing IaC.
- [ ] **BOOTSTRAP-02**: Every existing backend.tf (`envs/strapi`, `envs/frontend/staging`, `envs/frontend/prod`) is wired with `dynamodb_table = "dmair-terraform-locks"`. Each stack is `terraform init -reconfigure`'d. Plans remain zero-change after the rewire.
- [ ] **BOOTSTRAP-03**: Concurrent `terraform apply` from two operators is prevented by the lock table (verified by attempting and observing the lock contention).

### Refactor — Folder Layout

- [ ] **REFACTOR-01**: The folder layout migrates from `envs/<x>` to `live/dmair/<env>/<component>`. Specifically: `envs/strapi` → `live/dmair/prod/strapi`, `envs/frontend/prod` → `live/dmair/prod/frontend`, `envs/frontend/staging` → `live/dmair/staging/frontend`. State keys at `strapi/`, `frontend/staging/`, `frontend/prod/` remain at their current paths in the bucket (folder rename only).
- [ ] **REFACTOR-02**: Every resource address that moves uses a `moved {}` block so that `terraform plan` on each migrated stack reports **"No changes"**. This is the hard exit criterion for the refactor — no exceptions.
- [ ] **REFACTOR-03**: `live/dmair/staging/` slot is reserved (directory exists with at minimum a placeholder README) for the dmair-backend staging deploy.

### Documentation

- [ ] **DOCS-01**: README updated to describe the new `live/<project>/<env>/<component>` layout, the `bootstrap/` stack, and the DynamoDB lock table. The legacy "company-website production stack" framing is removed — the docs reflect that this repo owns three live stacks (strapi CMS, frontend prod, frontend staging) plus the new backend staging slot.

### Staging — dmair-backend Slot

- [ ] **STAGING-01**: `live/dmair/staging/backend/` Terraform stack provisions the AWS resources required for the dmair-backend staging deployment (EC2 + Elastic IP + Security Group + ECR + Secrets Manager scaffolding, sized for staging — exact composition to be settled at /gsd-discuss-phase). Targets `api-staging.flydmair.com`.
- [ ] **STAGING-02**: A DNS A-record for `api-staging.flydmair.com` points at the staging backend's Elastic IP. An ACM/Let's Encrypt cert for that hostname is acquirable from the EC2 host.
- [ ] **STAGING-03**: A GitHub OIDC IAM role + tag/prefix-scoped IAM policy lets `dmair-backend` CI deploy into `live/dmair/staging/*` without being able to mutate existing `cms-*` / `frontend-*` resources in the shared `dmair` AWS account. Scoping is verified by an explicit deny-by-exclusion test (CI role attempts to read or modify a frontend resource and is rejected).

## v2 Requirements

Deferred to future milestones — tracked but not in this roadmap.

### Production Slot

- **PROD-01**: `live/dmair/prod/backend/` production slot for dmair-backend (lifts from staging once staging proves out).

### Quality Tooling

- **QA-01**: `tflint` / `checkov` / `tfsec` integration with CI gate.
- **QA-02**: `terratest` harness for module-level smoke tests.
- **QA-03**: Automated drift detection (scheduled `terraform plan` reports).

### State-Key Cleanup

- **STATE-01**: Relocate state keys to match new folder layout (e.g. `strapi/terraform.tfstate` → `live/dmair/prod/strapi/terraform.tfstate`). Deferred — accepted as drift in v1.

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

Empty — will be populated by `/gsd-roadmapper` during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BOOTSTRAP-01 | TBD | Pending |
| BOOTSTRAP-02 | TBD | Pending |
| BOOTSTRAP-03 | TBD | Pending |
| REFACTOR-01 | TBD | Pending |
| REFACTOR-02 | TBD | Pending |
| REFACTOR-03 | TBD | Pending |
| DOCS-01 | TBD | Pending |
| STAGING-01 | TBD | Pending |
| STAGING-02 | TBD | Pending |
| STAGING-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 10 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 10 ⚠️ (expected until roadmap is created)

---
*Requirements defined: 2026-05-20*
*Last updated: 2026-05-20 after initial definition*
