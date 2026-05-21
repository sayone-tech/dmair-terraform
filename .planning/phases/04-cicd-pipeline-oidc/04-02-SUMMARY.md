---
phase: 04-cicd-pipeline-oidc
plan: 02
status: code-only-complete
---

# Plan 04-02 Summary — .github/workflows/terraform.yml

## Status

**code-only-complete.** Single GitHub Actions workflow covering both CICD-01 (PR-gated plan) and CICD-02 (merge-gated apply per stack via GitHub Environments).

## File

`.github/workflows/terraform.yml`

## Job graph (post DevOps review)

```
   pull_request OR push to main           workflow_dispatch
        (auto)                              (manual operator)
            │                                       │
            ▼                                       │
  ┌───────────────────┐                             │
  │  detect-changes   │                             │
  └─────────┬─────────┘                             │
            │                                       │
            ▼                                       │
  ┌────────────────────┐                            │
  │   plan (matrix)    │                            │
  │  fmt/validate/plan │                            │
  │  PR: comment       │                            │
  │  push: artifact    │                            │
  └────────────────────┘                            │
                                                    │
                       ┌────────────────────────────┴────────┐
                       ▼                                     ▼
                ┌────────────────┐                  ┌────────────────────┐
                │ apply-staging  │                  │  apply-prod        │
                │ live/dmair/    │                  │  bootstrap | ci |  │
                │ staging/* only │                  │  live/dmair/prod/* │
                │ no env gate    │                  │  environment: prod │
                │ Role: staging- │                  │  Required reviewer │
                │ apply          │                  │  Role: prod-apply  │
                └────────────────┘                  └────────────────────┘
```

**Apply is no longer triggered by `push: main`.** Per DevOps review, apply runs only on `workflow_dispatch` — the operator picks a single stack from a dropdown and runs the workflow manually.

## Stack-routing logic

`detect-changes` outputs the list of changed stacks based on `git diff`. Special-case: any change under `modules/` or `policies/` fans out to **every** stack (any resource in the graph could be affected). The two apply jobs filter the matrix to their respective stack subsets.

## Secrets used by the workflow

**Role ARNs (kept out of YAML per DevOps review):**

- `AWS_PLAN_ROLE_ARN`
- `AWS_STAGING_APPLY_ROLE_ARN`
- `AWS_PROD_APPLY_ROLE_ARN`

**Application sensitive vars (staging-backend stack only):**

- `STAGING_BACKEND_DB_PASSWORD`
- `STAGING_BACKEND_JWT_SECRET`
- `STAGING_BACKEND_MAIL_PASSWORD`
- `STAGING_BACKEND_ADMIN_PASSWORD`

The four app secrets are loaded on both plan and apply jobs (plan needs them too — terraform refuses to plan without all required vars defined).

## Why no `checkov` / `tfsec` job

The user-confirmed Phase 4 scope excluded a static security-scan job ("no managed test suite" per PROJECT.md). It's listed as a v2 improvement in [`OIDC.md`](../../../OIDC.md) §Future improvements.

## DevOps post-apply tasks

1. Apply `platform/oidc/` once (locally with the `dmair` profile, or via `terraform apply` as the bootstrapping operator). This creates the three IAM roles before the workflow can assume them.
2. Configure repo Settings → Environments → `prod` with required reviewers.
3. Add the four `STAGING_BACKEND_*` repo Secrets (same values used in Phase 3 `staging.auto.tfvars`).
4. Push a trivial no-op change to a feature branch and open a PR; confirm `plan` job runs and posts a PR comment, `apply-*` jobs do NOT run.
5. Merge the PR; confirm `apply-staging` auto-runs and `apply-prod` pauses for reviewer approval.
6. Approve; confirm `apply-prod` runs and exits clean.

## Verification evidence

See [`VERIFICATION.md`](./VERIFICATION.md) for the fillable evidence template.
