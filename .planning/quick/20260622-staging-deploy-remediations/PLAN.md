---
quick_id: 260622-dry
slug: staging-deploy-remediations
date: 2026-06-22
status: in-progress
---

# Quick Task: dmair-backend staging-deploy readiness remediations

Apply the must-fix remediations surfaced by the staging-deploy readiness audit of
`live/dmair/backend/staging/`. Backend-team-verified severity corrections are baked in.

**Invariant:** Live infra is sacred. `terraform plan` on `live/dmair/strapi/prod`,
`live/dmair/frontend/prod`, `live/dmair/frontend/staging` must still report **No changes**
after every commit. (Safe by construction: every file touched here is referenced only by
`live/dmair/backend/staging/` or is the out-of-band ops script — verified via grep.)

**Mode:** edit + `terraform plan` only. NO `terraform apply`. Atomic commit per fix.
Plans run with `AWS_PROFILE=dmair-mithin`.

## Ordered fixes

0. **[DEPLOY-BLOCKER]** `setup-oidc-roles.sh` — backend OIDC org `sayone-tech` → `DM-Air`
   (backend repo is `github.com/DM-Air/dmair-backend`; sub never matched). Keep
   `:ref:refs/heads/staging` scoping.
1. **[PLAN-BLOCKER]** `setup-oidc-roles.sh` Step 3 — add idempotent create-if-missing for
   `/dmair/staging/ingest_oauth_google_client_id` + `_client_secret` (REPLACE placeholders;
   same Google OAuth client as local-dev). `ssm.tf` reads them as data sources, so a fresh
   plan errors until they exist.
2. **[IAM / load-bearing]** `policies/ec2_app_runtime.tpl` — add `secretsmanager:DeleteSecret`
   to the ingest-refresh-token statement (app deletes the secret on mailbox disconnect).
   Resource already correct: `…:secret:dmair/ingest/google-refresh-token-*` (trailing `-*`).
3. **[FIRST-BOOT]** `user-data.sh` compose `&app-env` — set `TRIP_QUOTE_EXPIRY_ENABLED=false`
   (its first run mass-closes historical quotes to LOST) and `TRIP_COMPLETION_ENABLED=true`.
4. **[SECURITY/doc]** `user-data.sh` — document valkey password-less as accepted staging risk
   (host-local on the docker network only; app `REDIS_PASSWORD` empty default matches). No
   mismatched auth added. valkey:8 left as-is (RESP-compatible with Redis 7.4).
5. **[TUNING]** `user-data.sh` compose `&app-env` — `APP_HEAP_MIN=512m`, `APP_HEAP_MAX=1536m`
   (override Dockerfile 1g default for headroom on t4g.medium; inherited by admin-bootstrap
   via `<<: *app-env`). NOT boot-breaking — Dockerfile already defaults 512m/1g.

## Do NOT touch
FLYWAY_LOCATIONS (must stay absent), ECR repo/role perms, SG egress (incl. outbound 993),
the OAuth redirect URI, `db_engine_version="17"` (req is 16+ floor).

## Runbook (report, not code)
- GoDaddy A record `staging-api.flydmair.com` → EIP before first boot.
- Register `https://staging-api.flydmair.com/api/v1/admin/mailbox/oauth-callback` in the
  Google OAuth client's authorized redirect URIs.
- Seed a staging admin (admin-bootstrap) so someone can hit admin endpoints / Connect Mail.
