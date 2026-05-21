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

## Job graph

```
                       on: pull_request OR push to main
                                 │
                                 ▼
                       ┌───────────────────┐
                       │  detect-changes   │
                       │  (paths matrix)   │
                       └─────────┬─────────┘
                                 │
              ┌──────────────────┴──────────────────┐
              ▼                                     ▼
       ┌────────────┐                          (no-op if no changes)
       │   plan     │  matrix per stack
       │            │  - terraform fmt/validate/plan
       │            │  - PR: post plan as PR comment
       │            │  - push: upload tfplan artifact
       └─────┬──────┘
             │ (push to main only)
             ▼
    ┌────────┴───────────────┐
    ▼                        ▼
┌────────────────┐    ┌──────────────────┐
│ apply-staging  │    │  apply-prod      │
│ live/dmair/    │    │  bootstrap | ci |│
│ staging/* only │    │  live/dmair/     │
│                │    │  prod/*          │
│ Auto-applies   │    │                  │
│ (no reviewer)  │    │ environment: prod│
│                │    │ Required-reviewer│
│ Role: staging- │    │ gate. Role: prod-│
│ apply          │    │ apply            │
└────────────────┘    └──────────────────┘
```

## Stack-routing logic

`detect-changes` outputs the list of changed stacks based on `git diff`. Special-case: any change under `modules/` or `policies/` fans out to **every** stack (any resource in the graph could be affected). The two apply jobs filter the matrix to their respective stack subsets.

## Sensitive vars

The staging-backend stack's four sensitive vars (`db_password`, `jwt_secret_key`, `mail_password`, `admin_bootstrap_password`) are injected as `TF_VAR_*` env vars from repo Secrets:

- `STAGING_BACKEND_DB_PASSWORD`
- `STAGING_BACKEND_JWT_SECRET`
- `STAGING_BACKEND_MAIL_PASSWORD`
- `STAGING_BACKEND_ADMIN_PASSWORD`

These are loaded on both plan and apply jobs (plan needs them too — terraform refuses to plan without all required vars defined).

## Why no `checkov` / `tfsec` job

The user-confirmed Phase 4 scope excluded a static security-scan job ("no managed test suite" per PROJECT.md). It's listed as a v2 improvement in [`OIDC.md`](../../../OIDC.md) §Future improvements.

## DevOps post-apply tasks

1. Apply `ci/` once (locally with the `dmair` profile, or via `terraform apply` as the bootstrapping operator). This creates the three IAM roles before the workflow can assume them.
2. Configure repo Settings → Environments → `prod` with required reviewers.
3. Add the four `STAGING_BACKEND_*` repo Secrets (same values used in Phase 3 `staging.auto.tfvars`).
4. Push a trivial no-op change to a feature branch and open a PR; confirm `plan` job runs and posts a PR comment, `apply-*` jobs do NOT run.
5. Merge the PR; confirm `apply-staging` auto-runs and `apply-prod` pauses for reviewer approval.
6. Approve; confirm `apply-prod` runs and exits clean.

## Verification evidence

See [`VERIFICATION.md`](./VERIFICATION.md) for the fillable evidence template.
