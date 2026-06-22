---
quick_id: 260622-dry
slug: staging-deploy-remediations
date: 2026-06-22
status: complete
branch: fix/staging-deploy-remediations
---

# Summary: dmair-backend staging-deploy readiness remediations

Applied 6 must-fix remediations from the staging-deploy readiness audit as atomic
commits on `fix/staging-deploy-remediations`. No `terraform apply` performed.

## Commits (one per fix)

| Fix | Commit | File | Change |
|-----|--------|------|--------|
| 0 | fix(oidc): scope … DM-Air/dmair-backend | setup-oidc-roles.sh:33 | `BACKEND_ORG_REPO` sayone-tech → DM-Air (OIDC sub match) |
| 1 | fix(oidc): create ingest OAuth SSM params | setup-oidc-roles.sh (Step 3) | add idempotent create-if-missing for the two ingest_oauth params |
| 2 | fix(iam): grant DeleteSecret … | policies/ec2_app_runtime.tpl | + `secretsmanager:DeleteSecret` on refresh-token secret |
| 3 | fix(staging): first-boot trip toggles | user-data.sh (&app-env) | `TRIP_QUOTE_EXPIRY_ENABLED=false`, `TRIP_COMPLETION_ENABLED=true` |
| 4 | docs(staging): valkey password-less | user-data.sh (valkey) | comment: accepted staging risk + how to harden |
| 5 | chore(staging): JVM heap headroom | user-data.sh (&app-env) | `APP_HEAP_MIN=512m`, `APP_HEAP_MAX=1536m` |

## Live-infra-sacred verification (the gate)

`terraform plan` (AWS_PROFILE=dmair-mithin, -lock=false) after all commits:

- live/dmair/strapi/prod      → **No changes ✓** (exit 0)
- live/dmair/frontend/prod    → **No changes ✓** (exit 0)
- live/dmair/frontend/staging → **No changes ✓** (exit 0)

Safe by construction: every file touched is referenced only by
live/dmair/backend/staging/ or is the out-of-band ops script (verified via grep).
(`terraform init` on the live stacks reconciled provider cache and dirtied their
.terraform.lock.hcl — reverted via `git checkout`, working tree left pristine.)

## backend/staging plan (intended target — NOT applied)

Plan: 1 to add, 2 to change, 1 to destroy.
- aws_instance.app — updated in-place, only `user_data` hash changes (fixes 3/4/5).
  Non-destructive; lifecycle ignores only `ami`. user_data re-runs on next boot.
- module.ec2_runtime_policy…["ec2_app_runtime"] — in-place, `+DeleteSecret` (fix 2).
- aws_secretsmanager_secret_version.app — REPLACED. **Pre-existing drift**, NOT from
  this task (no commit touched secrets.tf/ssm.tf): the consolidated `dmair/staging/app`
  secret is rebuilt-from-SSM on every apply (guardrail #2). The live secret currently
  differs from the SSM-rendered value.

## ⚠ Apply-time caveat (for whoever applies the backend stack)

Per guardrail #2, applying will rebuild `dmair/staging/app` from `/dmair/staging/*` SSM
params. Confirm those hold REAL values first — especially `/dmair/staging/mail_password`
(still `PENDING_REPLACE_WITH_SENDGRID_API_KEY` in the bootstrap default) — or the apply
clobbers the live secret (SMTP 535, /actuator/health DOWN).

## Runbook (not code — operator steps)

- GoDaddy A record `staging-api.flydmair.com` → EIP before first boot.
- Register `https://staging-api.flydmair.com/api/v1/admin/mailbox/oauth-callback` in the
  Google OAuth client's authorized redirect URIs.
- Seed a staging admin (admin-bootstrap) to reach admin endpoints / Connect Mail.
- After backend/staging apply, feed the EC2 instance id into the dmair-backend GitHub
  secret and re-run setup-oidc-roles.sh with STAGING_EC2_INSTANCE_ID set to create the
  deploy role.

## Not touched (verified left alone)
FLYWAY_LOCATIONS (absent), ECR repo/role perms, SG egress (incl. outbound 993),
OAuth redirect URI, db_engine_version="17".
