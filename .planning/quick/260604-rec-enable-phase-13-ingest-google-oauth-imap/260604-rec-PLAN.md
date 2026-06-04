---
quick_id: 260604-rec
title: Enable Phase 13 ingest (Google OAuth/IMAP mailbox) on backend staging
status: planned
date: 2026-06-04
branch: feat/staging-ingest-oauth
---

# Quick Task 260604-rec: Enable Phase 13 ingest (Google OAuth/IMAP) on backend staging

## Goal

Wire the JetInsight email ingest feature on the **staging** backend stack: inject
Google OAuth client credentials + redirect URI into the consolidated app secret and
the app container's environment, and grant the EC2 instance role read/write on the
refresh-token secret in Secrets Manager. **Config + IAM only — no new compute.**

All edits live under `live/dmair/backend/staging/` plus the shared policy template
`policies/ec2_app_runtime.tpl`.

## Verified facts (read before planning)

- Domain variable is `var.staging_domain` (default `staging-api.flydmair.com`) — NOT `domain`.
- `data "aws_caller_identity" "current" {}` already exists at `live/.../staging/ec2.tf:68` —
  do NOT re-declare. ARNs are built as `${data.aws_caller_identity.current.account_id}` +
  `${var.aws_region}` (see ec2.tf:36).
- `modules/iam-policy/main.tf` renders each `.tpl` via `templatefile(..., var.template_vars[t])`.
  Extra keys in the vars map are harmless; a `${var}` referenced in the `.tpl` MUST exist in the map.
- App-env block `&app-env` is at user-data.sh:69; `MAIL_PASSWORD` is the last secret entry (line 90),
  using `$${VAR:?...}` (required-at-boot). New ingest vars use `$${VAR:-}` (optional-at-boot).
- `INGEST_SECRETS_REGION` (us-west-2) and `INGEST_SECRETS_REFRESH_TOKEN_SECRET_NAME`
  (`dmair/ingest/google-refresh-token`) are app `application.properties` defaults that already match
  staging — NOT set here.

## Tasks

### Task 1 — ssm.tf: add 2 OAuth data sources (commit)
- **files:** `live/dmair/backend/staging/ssm.tf`
- **action:** Add `data "aws_ssm_parameter"` for `ingest_oauth_google_client_id` and
  `ingest_oauth_google_client_secret` (`/dmair/staging/*`, `with_decryption = true`), matching the
  existing 4-param pattern. Extend the header comment with the two new out-of-band
  `put-parameter --type SecureString` commands (values come from the Google Cloud OAuth client — never committed).
- **verify:** `terraform validate`; both data sources present.
- **done:** Two new SecureString reads declared + documented.

### Task 2 — secrets.tf: inject 3 ingest keys into the app secret (commit)
- **files:** `live/dmair/backend/staging/secrets.tf`
- **action:** Add to the `jsonencode({...})` in `aws_secretsmanager_secret_version.app`:
  `INGEST_OAUTH_GOOGLE_CLIENT_ID`, `INGEST_OAUTH_GOOGLE_CLIENT_SECRET` (from the SSM data sources),
  `INGEST_OAUTH_GOOGLE_REDIRECT_URI = "https://${var.staging_domain}/api/v1/admin/mailbox/oauth-callback"`.
  Update the secret `description` to mention ingest OAuth.
- **verify:** `terraform validate`; 3 keys present; redirect URI uses `var.staging_domain`.
- **done:** App secret JSON carries the 3 ingest values.

### Task 3 — user-data.sh: add 3 optional app-env entries (commit)
- **files:** `live/dmair/backend/staging/user-data.sh`
- **action:** After `MAIL_PASSWORD` (line 90) in the `&app-env` block, add three entries using
  `$${VAR:-}` (optional, default empty — app must still boot if unset), keeping the `$$` template escape:
  `INGEST_OAUTH_GOOGLE_CLIENT_ID`, `INGEST_OAUTH_GOOGLE_CLIENT_SECRET`, `INGEST_OAUTH_GOOGLE_REDIRECT_URI`.
- **verify:** `terraform validate` (templatefile still parses); `$$` preserved; `:-` not `:?`.
- **done:** App container receives the 3 ingest vars when present.

### Task 4 — policies/ec2_app_runtime.tpl: refresh-token secret statement (commit)
- **files:** `policies/ec2_app_runtime.tpl`
- **action:** Add a SECOND `secretsmanager` statement (separate from the read-only `ReadAppSecret`)
  granting `GetSecretValue`, `PutSecretValue`, `CreateSecret`, `DescribeSecret` on a new template var
  `${ingest_refresh_token_secret_arn}` (name-prefix wildcard — MailboxSecretService creates the secret
  at first Connect and Secrets Manager appends a random suffix).
- **verify:** valid JSON; new Sid; references `${ingest_refresh_token_secret_arn}`.
- **done:** Instance role can create/read/write the refresh-token secret.

### Task 5 — iam.tf: pass the new template var (commit)
- **files:** `live/dmair/backend/staging/iam.tf`
- **action:** In `module "ec2_runtime_policy"` `template_vars.ec2_app_runtime`, add
  `ingest_refresh_token_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:dmair/ingest/google-refresh-token-*"`.
  `aws_caller_identity.current` already exists (ec2.tf:68) — do not re-declare.
- **verify:** `terraform validate`; `terraform plan` shows app-secret version updated (+3 keys),
  instance-role policy gains the refresh-token statement, 2 new SSM reads, and **NO destroy** of EC2/role/secret.
- **done:** Policy template receives the ARN; plan is non-destructive.

## must_haves

- truths:
  - Redirect URI is derived from `var.staging_domain`, not a hardcoded host.
  - Refresh-token ARN is a name-prefix wildcard (`...google-refresh-token-*`).
  - New env vars use `:-` (optional), existing ones keep `:?` (required).
  - No secret values are committed to terraform.
- artifacts:
  - `terraform plan` clean of destroys on `aws_instance.app`, `module.ec2_role`, `aws_secretsmanager_secret.app`.
- key_links:
  - `live/dmair/backend/staging/ssm.tf`
  - `live/dmair/backend/staging/secrets.tf`
  - `live/dmair/backend/staging/user-data.sh`
  - `policies/ec2_app_runtime.tpl`
  - `live/dmair/backend/staging/iam.tf`

## Out of scope / operator follow-ups (apply-time, not terraform)

1. `aws ssm put-parameter --type SecureString` the two `/dmair/staging/ingest_oauth_google_client_*` params.
2. Register redirect URI `https://<staging-domain>/api/v1/admin/mailbox/oauth-callback` on the Google OAuth client.
3. After apply+redeploy: run Connect Mail on staging OR seed `dmair/ingest/google-refresh-token`
   by copying the existing dev token.
