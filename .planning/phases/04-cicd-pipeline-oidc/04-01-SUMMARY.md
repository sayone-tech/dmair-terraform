---
phase: 04-cicd-pipeline-oidc
plan: 01
status: code-only-complete
---

# Plan 04-01 Summary — ci/ stack (three OIDC-trusted IAM roles)

## Status

**code-only-complete.** New `ci/` Terraform stack with three IAM roles. `terraform init` / `apply` deferred to DevOps.

## Files (commit fdb83b6 _(approx)_)

| File | Purpose |
|---|---|
| `ci/backend.tf` | S3 backend at key `ci/terraform.tfstate` with `use_lockfile = true`. |
| `ci/providers.tf` | Terraform `~> 1.15`; aws `5.91.0`; default_tags `{Project=dmair, Component=ci, ManagedBy=terraform}`. |
| `ci/variables.tf` | OIDC sub-claim patterns per role + state bucket ARN. |
| `ci/main.tf` | OIDC provider `data`-sourced from Phase 3; three roles (plan-readonly, staging-apply, prod-apply) with scoped trust + permission policies. |
| `ci/outputs.tf` | Role ARNs + OIDC provider ARN. |

`terraform fmt -check` clean.

## Roles

1. **dmair-terraform-plan-readonly** — assumed on PRs + push-to-main; refresh-only `Describe*` / `Get*` / `List*` perms plus state-bucket read + `.tflock` write. NO `secretsmanager:GetSecretValue`. NO writes / destroys / creates.
2. **dmair-terraform-staging-apply** — assumed on push-to-main; inherits plan-readonly + scoped staging writes (tag `Environment=staging` OR name prefix `dmair-staging-*` / `dmair-backend-staging-*` only). IAM scope blocks `Create*` outside the staging prefixes — CICD-01 #3 no-escalation invariant.
3. **dmair-terraform-prod-apply** — assumed only with OIDC sub `environment:prod`. The `prod` GitHub Environment with required reviewers is the load-bearing safety control. IAM scope is broad on prod prefixes (`strapi-*`, `frontend-*`, `dmair-prod-*`, `cms-*`, `github-actions-*`) but never wildcarded outside them.

## Hand-off note

OIDC identity provider currently lives in `live/dmair/staging/backend/oidc.tf` (Phase 3). The `ci/` stack `data`-sources it. Future improvement: `terraform state mv` it into `ci/main.tf` to decouple account-wide trust from the staging-backend stack lifecycle. Tracked in [`OIDC.md`](../../../OIDC.md) §Future improvements.
