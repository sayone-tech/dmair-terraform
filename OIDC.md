# OIDC — Trust Provider + Role Inventory

This document is the source of truth for the **GitHub Actions OIDC** integration that drives `terraform plan` / `terraform apply` for this repository and the `dmair-backend` repository's staging deploys.

It satisfies **CICD-02** Phase 4 success criterion: every OIDC role used by automation is enumerated with its trust subject and permission scope.

---

## Account-wide identity provider

| Field | Value |
|---|---|
| Provider URL | `https://token.actions.githubusercontent.com` |
| Audience | `sts.amazonaws.com` |
| Thumbprint | `6938fd4d98bab03faadb97b34396831e3780aea1` (GitHub's current Actions OIDC root, validated 2026-05) |
| Created in | [`live/dmair/staging/backend/oidc.tf`](live/dmair/staging/backend/oidc.tf) (Phase 3) |
| Referenced by | [`ci/main.tf`](ci/main.tf) via `data "aws_iam_openid_connect_provider" "github"` (Phase 4) |

> **Future improvement:** the OIDC provider currently lives inside the `live/dmair/staging/backend/` stack — that means destroying the staging backend would tear down all OIDC trust account-wide. Move it to the `ci/` stack via:
> ```sh
> # source-side: comment out aws_iam_openid_connect_provider.github in live/dmair/staging/backend/oidc.tf
> # destination-side: add it to ci/main.tf
> terraform -chdir=ci state mv -state-out=ci/terraform.tfstate \
>   '-state=live/dmair/staging/backend/terraform.tfstate' \
>   aws_iam_openid_connect_provider.github \
>   aws_iam_openid_connect_provider.github
> ```
> Tracked as a v2 improvement; the current setup is correct but coupled.

---

## Role inventory

There are **four** OIDC-trusted IAM roles. Three belong to the `dmair-terraform` CI; one is a cross-repo contract consumed by the `dmair-backend` repo.

### 1. `dmair-terraform-plan-readonly`

| Field | Value |
|---|---|
| Defined in | [`ci/main.tf`](ci/main.tf) |
| Assumed by | `dmair-terraform` CI |
| Workflow job | `plan` (every PR + push-to-main) |
| OIDC sub claim allowed | `repo:sayone-tech/dmair-terraform:pull_request*`, `repo:sayone-tech/dmair-terraform:ref:refs/heads/main*` |
| Audience | `sts.amazonaws.com` |
| Max session | 1 hour |

**Scope.** Read-only across the account, sufficient for `terraform plan` against every stack:

- `s3:GetObject`/`ListBucket` on the state bucket (plus `PutObject`/`DeleteObject` strictly on `*.tflock` for state-locking)
- `Describe*` / `Get*` / `List*` on EC2, VPC, RDS, ECR, IAM, CloudFront, S3 bucket-configs, Logs, SSM, Route53, ACM, Budgets
- **Excluded** by design: `secretsmanager:GetSecretValue` (secret values stay opaque to plan), any `Put*` / `Delete*` / `Create*` / `Update*` action

### 2. `dmair-terraform-staging-apply`

| Field | Value |
|---|---|
| Defined in | [`ci/main.tf`](ci/main.tf) |
| Assumed by | `dmair-terraform` CI |
| Workflow job | `apply-staging` (push-to-main only, no reviewer gate) |
| OIDC sub claim allowed | `repo:sayone-tech/dmair-terraform:ref:refs/heads/main` |
| Audience | `sts.amazonaws.com` |
| Max session | 1 hour |

**Scope.** `plan-readonly` permission set + tightly scoped write/delete on staging resources:

- **State writes** on `${state_bucket}/staging/*` and `${state_bucket}/frontend/staging/*` only
- **EC2/VPC** writes conditional on `aws:RequestTag/Environment=staging`
- **RDS** writes on ARNs matching `db:dmair-staging*` / `subgrp:dmair-staging*`
- **Secrets Manager** writes on `secret:dmair/staging/*`
- **ECR** writes on `repository/dmair-backend`
- **CloudWatch Logs** writes on `log-group:/dmair/staging*`
- **IAM** writes on role / instance-profile / policy ARNs matching `dmair-staging-*` or `dmair-backend-staging-*` only — **no `iam:Create*` outside this name prefix** (CICD-01 #3 — no-escalation invariant)
- **Budgets** writes on `budget/dmair-staging-*`

### 3. `dmair-terraform-prod-apply`

| Field | Value |
|---|---|
| Defined in | [`ci/main.tf`](ci/main.tf) |
| Assumed by | `dmair-terraform` CI |
| Workflow job | `apply-prod` (push-to-main + `environment: prod`) |
| OIDC sub claim allowed | `repo:sayone-tech/dmair-terraform:environment:prod` |
| Audience | `sts.amazonaws.com` |
| Max session | 1 hour |

**Scope.** `plan-readonly` permission set + write/delete on the prod stacks. The primary safety control is the **`prod` GitHub Environment** with required reviewers — IAM scoping is belt-and-suspenders:

- **State writes** account-wide on the state bucket (because this role is the only one that can apply `bootstrap/` itself)
- **Bootstrap S3 bucket** management (the state bucket is managed by `bootstrap/`)
- **EC2/VPC/CloudFront/S3** writes account-wide (prod resources don't all share a single tag namespace yet — a v2 tagging discipline will tighten this)
- **Secrets Manager** writes account-wide (prod secrets live under several name prefixes)
- **IAM** writes on role / instance-profile / policy / user ARNs matching `strapi-*`, `frontend-*`, `dmair-prod-*`, `cms-*`, `github-actions-*` — **no wildcard `iam:CreateUser`** (CICD-01 #3 — no escalation outside known prod prefixes)
- **ECR** writes on `repository/*` (prod has the frontend deploy users + the strapi ECR repo; further scoping is a v2 improvement)
- **CloudWatch Logs** writes account-wide

> **Why broader than staging-apply.** The repo currently has prod resources spread across multiple legacy naming conventions (`strapi-*`, `frontend-*`, `cms-*`, plus a few hardcoded names from before Phase 2). A v2 cleanup pass tagging every prod resource with `Environment=prod` would let us tighten this scope to a single tag condition. Until then, the `prod` Environment's required-reviewers gate is the load-bearing safety control.

### 4. `dmair-backend-staging-deploy`

| Field | Value |
|---|---|
| Defined in | [`live/dmair/staging/backend/oidc.tf`](live/dmair/staging/backend/oidc.tf) (Phase 3) |
| Assumed by | **`dmair-backend` repo's CI** (cross-repo contract) |
| Workflow job | `deploy-staging` in `bere-creator/dmair-backend` |
| OIDC sub claim allowed | `repo:sayone-tech/dmair-backend:ref:refs/heads/staging`, `repo:sayone-tech/dmair-backend:environment:staging` |
| Audience | `sts.amazonaws.com` |
| Max session | 1 hour |

**Scope.** Application-deploy actions only — no terraform plan/apply privileges:

- **ECR** auth + push/pull on `repository/dmair-backend` only
- **Secrets Manager** `GetSecretValue` on `secret:dmair/staging/app` only
- **SSM** `SendCommand` / `StartSession` / `DescribeInstanceInformation` / `GetCommandInvocation` on `dmair-staging-ec2` instance ARN + the `AWS-RunShellScript` document

**Deny-by-exclusion (STAGING-03).** Because the resource ARNs are explicit and not wildcarded, any attempt by this role to touch `cms-*` / `frontend-*` / `strapi-*` / other-project resources returns `AccessDenied` — the absence of an Allow on those ARNs is the deny.

> **Cross-repo contract.** This role name (`dmair-backend-staging-deploy`) and the OIDC sub-claim pattern are baked into the `dmair-backend` repo's `.github/workflows/deploy-staging.yml`. **Renaming either is expensive** and requires a coordinated change across both repos.

---

## GitHub Environments — required reviewers

Configure under repo Settings → Environments:

### `prod`

- **Required reviewers:** at least 1 (recommended: 2). List specific GitHub accounts / teams.
- **Wait timer:** 0 minutes (optional — set if you want a cooling-off period before apply can run).
- **Deployment branches:** restrict to `main` only.
- **Environment secrets:** none currently (sensitive vars live in repo Secrets, not env Secrets, because the staging plan job also needs them).

When a `terraform.yml` workflow run reaches the `apply-prod` job, GitHub pauses and requests approval from a listed reviewer. The OIDC token issued for that job will only include `environment:prod` in the `sub` claim if the run is gated by this Environment — that's the IAM-side enforcement.

### `staging` (optional, not required by current setup)

The current `dmair-terraform-staging-apply` role does not require a GitHub Environment. If you want to add one (e.g. for environment-scoped secrets):

- Add `environment: staging` to the `apply-staging` job in `.github/workflows/terraform.yml`
- Add `repo:sayone-tech/dmair-terraform:environment:staging` to `var.staging_apply_subjects` in [`ci/variables.tf`](ci/variables.tf)
- Re-apply the `ci/` stack

---

## Repository Secrets used by automation

Configured under repo Settings → Secrets and variables → Actions → Repository secrets:

### Role ARNs (DevOps-review feedback — kept out of workflow YAML)

| Secret | Used by | Purpose |
|---|---|---|
| `AWS_PLAN_ROLE_ARN` | `plan` job | ARN of `dmair-terraform-plan-readonly` |
| `AWS_STAGING_APPLY_ROLE_ARN` | `apply-staging` job | ARN of `dmair-terraform-staging-apply` |
| `AWS_PROD_APPLY_ROLE_ARN` | `apply-prod` job | ARN of `dmair-terraform-prod-apply` |

> ARNs aren't credentials, but keeping them out of source removes account-id surface area for casual recon and provides a clean indirection point for future rotations or multi-account splits.

### Application-level sensitive vars

| Secret | Used by | Purpose |
|---|---|---|
| `STAGING_BACKEND_DB_PASSWORD` | `plan` + `apply-staging` (only when staging-backend stack changes) | RDS master/app password |
| `STAGING_BACKEND_JWT_SECRET` | same | HS512 signing key for the backend app |
| `STAGING_BACKEND_MAIL_PASSWORD` | same | SendGrid API key |
| `STAGING_BACKEND_ADMIN_PASSWORD` | same | Initial admin bootstrap password |

These map 1:1 to `var.db_password` / `jwt_secret_key` / `mail_password` / `admin_bootstrap_password` in [`live/dmair/staging/backend/variables.tf`](live/dmair/staging/backend/variables.tf) via `TF_VAR_*` env vars in the workflow.

---

## Trust subject reference

GitHub Actions OIDC token `sub` claim formats — for understanding what the `StringLike` conditions in the trust policies actually match:

| Workflow context | `sub` claim |
|---|---|
| Pull request | `repo:<org>/<repo>:pull_request` |
| Push to a branch | `repo:<org>/<repo>:ref:refs/heads/<branch>` |
| Push to a tag | `repo:<org>/<repo>:ref:refs/tags/<tag>` |
| Job running with `environment: <env>` | `repo:<org>/<repo>:environment:<env>` |
| Reusable workflow | `repo:<org>/<repo>:job_workflow_ref:<org>/<repo>/.github/workflows/<file>@<ref>` |

This list lives in [GitHub's docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#example-subject-claims) — keep this section in sync if the upstream changes.

---

## Verification

See [`.planning/phases/04-cicd-pipeline-oidc/VERIFICATION.md`](.planning/phases/04-cicd-pipeline-oidc/VERIFICATION.md) for the Phase 4 verification template.

Key checks DevOps runs after applying `ci/` and merging the workflow:

1. **PR trigger:** open a no-op PR to main. Confirm `plan` job runs, posts a comment, and `apply-*` jobs do NOT run.
2. **Push trigger to staging:** merge a staging-only change. Confirm `apply-staging` runs auto, `apply-prod` is skipped via filter.
3. **Push trigger to prod:** merge a prod-affecting change. Confirm `apply-prod` pauses for the Environment reviewer; after approval, apply runs and finishes clean.
4. **Escalation guard:** attempt to add a non-prefix-matching IAM role via a PR (e.g. `aws_iam_role.escalation` with name `not-in-scope-role`). Confirm `terraform plan` succeeds (plan is broad) but `terraform apply` from the prod-apply or staging-apply role fails with `AccessDenied` at apply time — CICD-01 #3 enforced.

---

## Future improvements (v2 tracked)

- Move the OIDC identity provider from `live/dmair/staging/backend/oidc.tf` to `ci/main.tf` via `terraform state mv`. Decouples account-wide trust from the staging backend stack lifecycle.
- Tag every prod resource with `Environment=prod` so `dmair-terraform-prod-apply` can tighten its scope from name-prefix lists to a single tag condition.
- Add a `staging` GitHub Environment with environment-scoped secrets if the backend secrets need separate rotation cadence from the rest of the repo.
- Add `checkov` or `tfsec` static security scan as a non-blocking advisory job in the plan workflow.
