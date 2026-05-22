---
phase: 04-cicd-pipeline-oidc
plan: 01
status: code-only-complete
---

# Plan 04-01 Summary — IAM Roles for GitHub Actions OIDC (manual ops setup)

## Status

**code-only-complete.** Per DevOps PR feedback, the four OIDC-trusted IAM roles + the GitHub Actions OIDC identity provider are **not** managed by Terraform. They are created out-of-band by ops following the procedure in [`docs/iam-oidc/README.md`](../../../docs/iam-oidc/README.md). This plan ships the JSON templates with placeholders + the README walking through the setup.

## What landed

| File | Purpose |
|---|---|
| `docs/iam-oidc/README.md` | Setup walkthrough: create the OIDC IDP once, render templates with `ACCOUNT_ID` / `ORG/REPO` placeholders, run the `aws iam create-role` + `put-role-policy` sequence, add repo Secrets, configure the `prod` GitHub Environment, enable branch protection on `main`. |
| `dmair-terraform-plan-readonly-trust.json` + `-permissions.json` | Plan-readonly role: PR + push-to-main trust; refresh-only `Describe/Get/List` perms + state-bucket read + `.tflock` RW. |
| `dmair-terraform-staging-apply-trust.json` + `-permissions.json` | Staging-apply role: trust restricted to `ref:refs/heads/main`; scoped staging writes (tag `Environment=staging` OR name prefix `dmair-staging-*` / `dmair-backend-staging-*` only). |
| `dmair-terraform-prod-apply-trust.json` + `-permissions.json` | Prod-apply role: trust restricted to `environment:prod` (so the role can only be assumed once the GitHub Environment reviewer-gate has fired); broader prod-prefix scope. |
| `dmair-backend-staging-deploy-trust.json` + `-permissions.json` | Cross-repo role assumed by the dmair-backend repo's CI; ECR push/pull + Secrets read + SSM SendCommand/StartSession on the staging EC2 only. |

All JSON contains placeholders (`ACCOUNT_ID`, `ORG/REPO`, `BACKEND_ORG/BACKEND_REPO`, `STAGING_EC2_INSTANCE_ID`) — safe to commit; ops substitutes real values locally and the rendered output is never committed.

## Why manual (not Terraform-managed)

Captured in [`docs/iam-oidc/README.md`](../../../docs/iam-oidc/README.md) §Design notes. Headline: chicken-and-egg (the roles run terraform apply; managing them with Terraform forces a bootstrap-yourself loop), separation of concerns (IAM trust is a security boundary, not app-dev iteration), and faster rotation (`update-assume-role-policy` is one API call).

## What was deleted from earlier commits

- `platform/oidc/` Terraform stack (5 files) — superseded by the docs/iam-oidc/ JSON templates.
- `policies/tf_plan_readonly.tpl`, `policies/tf_staging_apply.tpl`, `policies/tf_prod_apply.tpl`, `policies/github_app_deploy.tpl` — orphaned since platform/oidc/ was their only consumer.
- `live/dmair/backend/staging/oidc.tf` — the `dmair-backend-staging-deploy` role is also ops-managed now. The data lookup on the OIDC IDP is gone too (nothing in the stack uses it).
- `OIDC.md` at repo root — content folded into `docs/iam-oidc/README.md`.

## What stays Terraform-managed

- `policies/ec2_app_runtime.tpl` — used by the EC2 instance role in `live/dmair/backend/staging/iam.tf`. That role is a normal IAM service role for EC2 (`Principal: ec2.amazonaws.com`), not an OIDC federated role, so Terraform management remains appropriate.
- `modules/iam-policy`, `modules/iam-role` — still used by the live stacks.
