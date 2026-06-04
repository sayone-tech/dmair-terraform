---
quick_id: 260604-rec
title: Enable Phase 13 ingest (Google OAuth/IMAP mailbox) on backend staging
status: complete
date: 2026-06-04
branch: feat/staging-ingest-oauth
---

# Quick Task 260604-rec — Summary

Enabled the JetInsight email ingest feature (Google OAuth / IMAP mailbox) on the
**dmair-backend staging** stack. Config + IAM only — no new compute, no resource
replacement. Worked on branch `feat/staging-ingest-oauth`, atomic commits, NOT applied
(operator applies after review/merge).

## Changes (5)

1. **`live/dmair/backend/staging/ssm.tf`** — added two `aws_ssm_parameter` data sources
   (`ingest_oauth_google_client_id`, `ingest_oauth_google_client_secret`, both
   `/dmair/staging/*` SecureString, `with_decryption = true`) and documented the two
   out-of-band `put-parameter` setup commands in the header.
2. **`live/dmair/backend/staging/secrets.tf`** — added `INGEST_OAUTH_GOOGLE_CLIENT_ID`,
   `INGEST_OAUTH_GOOGLE_CLIENT_SECRET` (from SSM) and `INGEST_OAUTH_GOOGLE_REDIRECT_URI`
   (`https://${var.staging_domain}/api/v1/admin/mailbox/oauth-callback`, non-secret) to the
   consolidated `dmair/staging/app` secret JSON; updated the secret `description`.
3. **`live/dmair/backend/staging/user-data.sh`** — added the three `INGEST_OAUTH_GOOGLE_*`
   entries to the `&app-env` block after `MAIL_PASSWORD`, using `$${VAR:-}` (optional at boot)
   with the `$$` templatefile escape preserved.
4. **`policies/ec2_app_runtime.tpl`** — added a second secretsmanager statement
   (`ManageIngestRefreshTokenSecret`) granting `Get/Put/Create/DescribeSecret` on a new
   template var `ingest_refresh_token_secret_arn` (name-prefix wildcard), separate from the
   read-only `ReadAppSecret`.
5. **`live/dmair/backend/staging/iam.tf`** — passed
   `ingest_refresh_token_secret_arn = arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:dmair/ingest/google-refresh-token-*`
   into `module "ec2_runtime_policy"`. `aws_caller_identity.current` already existed
   (ec2.tf:68) — not re-declared.

## Commits (on `feat/staging-ingest-oauth`)

- Task 1 — ssm.tf data sources
- Task 2 — secrets.tf app-secret keys
- Task 3 — user-data.sh app-env vars
- Tasks 4+5 — ec2_app_runtime.tpl statement + iam.tf wiring (landed together; the template
  var and its caller are interdependent, so splitting them would leave an un-`validate`-able tree)

## Validation

- `terraform fmt -recursive -check` → **clean**.
- `terraform validate` → **Success**.
- `terraform plan` → `Plan: 0 to add, 3 to change, 0 to destroy.` All three are **in-place**:
  `aws_instance.app` (user_data), `aws_secretsmanager_secret.app` (description), and
  `module.ec2_runtime_policy.aws_iam_policy.this["ec2_app_runtime"]` (gains the
  `ManageIngestRefreshTokenSecret` statement). **No forced replacement, no destroy** — the
  live-infra invariant holds.
- The plan ultimately exits non-zero because the two new `/dmair/staging/ingest_oauth_google_*`
  SSM SecureString params do not exist yet. This is **operator follow-up #1**, a documented
  apply-time prerequisite — not a code defect. The app-secret version's 3 new keys will render
  once those params are created.
- `terraform apply` was **not** run (operator applies after review/merge).

## Notes

- Decided NOT to set `INGEST_SECRETS_REGION` / `INGEST_SECRETS_REFRESH_TOKEN_SECRET_NAME` in
  user-data — they already match the app's `application.properties` defaults for staging.
- `ec2_app_runtime.tpl` is consumed only by the staging stack, so adding the new template var
  reference breaks no other caller.
- Local `live/dmair/backend/staging/.terraform.lock.hcl` was created by `terraform init` during
  validation; left untracked (out of scope).

## Addendum — pre-existing OIDC budgets fix (folded in per user direction)

CI's plan on the branch surfaced an unrelated, pre-existing failure:
`budgets:ListTagsForResource` AccessDenied on the `dmair-terraform-plan-readonly` role when the
provider refreshes `aws_budgets_budget` (`budget.tf`, not touched by this task). The refresh block
granted `budgets:Describe*` + `budgets:View*` but not the tag-listing action.

**Scoped to plan-readonly only.** Initially added to all three OIDC templates (commit `853efb2`),
then reverted the staging-apply / prod-apply edits (commit `89a56d9`) on discovering that the
in-flight **PR #9 (fix/oidc-iam-tagpolicy)** already adds the identical line to both apply files —
keeping it here would be an add/add conflict. PR #9 does NOT touch `plan-readonly`, and CI runs
`plan` under that role, so the plan-readonly fix is the unique piece that unblocks the CI budget
refresh and stays in this PR. Net OIDC change in PR #10: plan-readonly +1 line. Requires ops to
re-apply the plan-readonly inline policy (`put-role-policy`, idempotent).

## Operator follow-ups (apply-time, NOT terraform)

1. Set the two SSM SecureString params before apply:
   - `/dmair/staging/ingest_oauth_google_client_id`
   - `/dmair/staging/ingest_oauth_google_client_secret`
2. Register redirect URI `https://<staging-domain>/api/v1/admin/mailbox/oauth-callback` on the
   Google OAuth client.
3. After apply + redeploy: run Connect Mail on staging OR seed `dmair/ingest/google-refresh-token`
   by copying the existing dev token.
4. Re-apply the **plan-readonly** OIDC inline policy so the `budgets:ListTagsForResource` fix
   takes effect (`aws iam put-role-policy ...`, idempotent — see docs/iam-oidc/README.md). The
   staging-apply / prod-apply equivalents land via PR #9.
