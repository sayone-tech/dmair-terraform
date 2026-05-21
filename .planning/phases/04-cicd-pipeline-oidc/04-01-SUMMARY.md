---
phase: 04-cicd-pipeline-oidc
plan: 01
status: code-only-complete
---

# Plan 04-01 Summary — platform/oidc/ stack (three OIDC-trusted IAM roles)

## Status

**code-only-complete.** New `platform/oidc/` Terraform stack with three IAM roles. `terraform init` / `apply` deferred to DevOps.

## Files (commit fdb83b6 _(approx)_)

| File | Purpose |
|---|---|
| `platform/oidc/backend.tf` | S3 backend at key `platform/oidc/terraform.tfstate` with `use_lockfile = true`. |
| `platform/oidc/providers.tf` | Terraform `~> 1.15`; aws `5.91.0`; default_tags `{Project=dmair, Component=ci, ManagedBy=terraform}`. |
| `platform/oidc/variables.tf` | OIDC sub-claim patterns per role + state bucket ARN. |
| `platform/oidc/main.tf` | GitHub OIDC IDP + three terraform CI roles (plan-readonly, staging-apply, prod-apply) composed via `modules/iam-policy` (renders `policies/tf_*.tpl`) + `modules/iam-role`. |
| `platform/oidc/outputs.tf` | IDP ARN + three role ARNs. |

`terraform fmt -check` clean.

## Permission policies (templated)

Three new IAM policy templates land in `policies/`:

- `tf_plan_readonly.tpl` — refresh-only `Describe*` / `Get*` / `List*` across the account, state-bucket read, `.tflock` write. **No `secretsmanager:GetSecretValue`**. No mutations.
- `tf_staging_apply.tpl` — plan-readonly statements + scoped staging writes (RDS / Secrets / ECR / Logs / Budgets on `dmair-staging-*` name prefix; EC2/VPC conditional on `aws:RequestTag/Environment=staging`; IAM mutate only on `dmair-staging-*` / `dmair-backend-staging-*` prefixes).
- `tf_prod_apply.tpl` — plan-readonly statements + broader prod-prefix scope (`strapi-*`, `frontend-*`, `dmair-prod-*`, `cms-*`, `github-actions-*`). Required-reviewer Environment gate is the primary safety control.

Templates are rendered into managed `aws_iam_policy` resources by `modules/iam-policy`; each role attaches the corresponding policy ARN via `modules/iam-role`. This matches the existing Strapi / Frontend pattern.

## Roles

1. **dmair-terraform-plan-readonly** — assumed on PRs + push-to-main.
2. **dmair-terraform-staging-apply** — assumed on workflow_dispatch from `main`. IAM `Create*` blocked outside the staging prefixes (CICD-01 #3 no-escalation invariant).
3. **dmair-terraform-prod-apply** — assumed only with OIDC sub `environment:prod`. The `prod` GitHub Environment with required reviewers is the load-bearing safety control.

## OIDC identity provider

The account-wide `aws_iam_openid_connect_provider.github` is created in this stack (`platform/oidc/main.tf`). Sibling stacks (`live/dmair/backend/staging/oidc.tf` — the `dmair-backend-staging-deploy` role) reference it via `data "aws_iam_openid_connect_provider"`. Apply `platform/oidc/` BEFORE any stack that defines OIDC-trusted roles.
