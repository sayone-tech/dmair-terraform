---
phase: 04-cicd-pipeline-oidc
plan: 02
status: code-only-complete
---

# Plan 04-02 Summary — .github/workflows/terraform.yml

## Status

**code-only-complete.** Single GitHub Actions workflow covering both CICD-01 (PR-gated plan) and CICD-02 (manual `workflow_dispatch` apply per stack, with `prod` GitHub Environment gating).

## File

`.github/workflows/terraform.yml`

## Job graph

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
                │ if stack ends  │                  │  if stack is       │
                │ in /staging    │                  │  bootstrap OR ends │
                │ no env gate    │                  │  in /prod          │
                │ Role: staging- │                  │  environment: prod │
                │ apply          │                  │  Required reviewer │
                │                │                  │  Role: prod-apply  │
                └────────────────┘                  └────────────────────┘
```

**Apply is no longer triggered by `push: main`.** Per DevOps review, apply runs only on `workflow_dispatch` — the operator picks a single stack from a dropdown and runs the workflow manually.

## Stack list

The workflow's `detect-changes` matrix + `workflow_dispatch` choice options list five workloads:

- `bootstrap`
- `live/dmair/strapi/prod`
- `live/dmair/frontend/prod`
- `live/dmair/frontend/staging`
- `live/dmair/backend/staging`

(`platform/oidc` was removed — that stack no longer exists; the OIDC IDP + 3 CI roles are created manually per `docs/iam-oidc/`.)

## Stack-routing logic

`detect-changes` outputs the list of changed stacks based on `git diff`. Special-case: any change under `modules/` or `policies/` fans out to **every** stack (any resource in the graph could be affected). The two apply jobs filter:

- `apply-staging`: `endsWith(stack, '/staging')` → routes the two staging stacks.
- `apply-prod`: `stack == 'bootstrap' || endsWith(stack, '/prod')` → routes bootstrap + the two prod stacks.

## Secrets used by the workflow

**Role ARNs (kept out of YAML — set by ops after creating the roles per `docs/iam-oidc/README.md`):**

- `AWS_PLAN_ROLE_ARN` → `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-plan-readonly`
- `AWS_STAGING_APPLY_ROLE_ARN` → `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-staging-apply`
- `AWS_PROD_APPLY_ROLE_ARN` → `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-prod-apply`

**Application sensitive vars (staging-backend stack only):**

- `STAGING_BACKEND_DB_PASSWORD`
- `STAGING_BACKEND_JWT_SECRET`
- `STAGING_BACKEND_MAIL_PASSWORD`
- `STAGING_BACKEND_ADMIN_PASSWORD`

The four app secrets are loaded on both plan and apply jobs (plan needs them too — terraform refuses to plan without all required vars defined).

## DevOps post-apply tasks

1. Follow [`docs/iam-oidc/README.md`](../../../docs/iam-oidc/README.md) to create the OIDC IDP + 3 terraform CI roles + the dmair-backend-staging-deploy role.
2. Add the 3 role ARNs + 4 app secrets to repo Secrets.
3. Configure the `prod` GitHub Environment with required reviewers.
4. Enable branch protection on `main` (require `terraform / plan` status checks).
5. Smoke-test: PR plan, push staging dispatch, push prod dispatch with reviewer gate, no-escalation probe.

## Verification

See [`VERIFICATION.md`](./VERIFICATION.md).
