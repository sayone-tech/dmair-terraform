---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-05-21T03:56:49.250Z"
last_activity: 2026-05-21
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 6
  completed_plans: 0
  percent: 0
---

# STATE: dmair-terraform

**Last Updated:** 2026-05-20

Last activity: 2026-06-04 - Completed quick task 260604-rec: Enable Phase 13 ingest (Google OAuth/IMAP) on backend staging

## Project Reference

**Core Value:** Live infra is sacred — `terraform plan` on every existing live stack must report "No changes" after every refactor commit. The dmair-backend staging slot is delivered on top of that invariant.

**Current Focus:** Phase 01 — bootstrap-state-backend

## Current Position

Phase: 01 (bootstrap-state-backend) — CODE-COMPLETE, AWAITING DEVOPS APPLY
Plan: 6 of 6 (all six plans code-only-complete)
**Phase:** 1 — Bootstrap State Backend
**Status:** All six plans landed as code-only commits on `feature/aws-deployment`. DevOps gates (terraform init/apply, four-stack zero-change verification, two-terminal lock contention proof) deferred per user direction. See `.planning/phases/01-bootstrap-state-backend/DEVOPS-HANDOFF.md` for the consolidated apply sequence.
**Progress:** [░░░░░░░░░░] 0% (0 / 3 phases complete — Phase 1 not yet DevOps-verified)

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases planned | 3 |
| Phases complete | 0 |
| v1 requirements mapped | 10 / 10 |
| Active milestone | Phase 9 — Refactor + State Backend |
| Mode | yolo |
| Granularity | coarse |

## Accumulated Context

### Key Decisions (carried from PROJECT.md)

- **Region:** `us-west-2` for all stacks (existing + new staging). EC2 `prevent_destroy = true` blocks a region migration.
- **Backend staging DNS:** `staging-api.flydmair.com` — avoids collision with existing `staging.flydmair.com` (frontend CloudFront).
- **Layout:** `live/dmair/<component>/<env>` — project-keyed under `dmair`, matches existing AWS profile name.
- **Account topology:** single shared `dmair` AWS account; isolation deferred. OIDC scoping in Phase 3 must keep dmair-backend CI from reaching CMS/frontend resources.
- **Bootstrap stack:** `terraform import` the existing `dmair-terraform-prod` bucket — state backend becomes self-describing IaC. No DynamoDB lock table; locking uses Terraform 1.10+'s S3-native `use_lockfile = true` (decided 2026-05-20, quick-task 260520-ntp).
- **Terraform pin:** `required_version = "~> 1.15"` across `bootstrap/` and all `envs/*/providers.tf` — `use_lockfile` requires ≥ 1.10; workstation runs 1.15.3.
- **State keys:** stay at current paths during folder rename. Bucket layout drift is accepted; relocation tracked as v2 STATE-01.

### Open Todos

- [ ] `/gsd-plan-phase 1` — decompose Phase 1 (Bootstrap State Backend) into executable plans
- [ ] `/gsd-plan-phase 2` — after Phase 1 ships
- [ ] `/gsd-plan-phase 3` — after Phase 2 ships

### Blockers

None. Phase 1 has no upstream dependency.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260520-ntp | Drop DynamoDB locking from Phase 1, use S3-native use_lockfile and bump Terraform pin to ~> 1.15 | 2026-05-20 | 015809f | [260520-ntp-drop-dynamodb-locking-from-phase-1-use-s](./quick/260520-ntp-drop-dynamodb-locking-from-phase-1-use-s/) |
| 260604-rec | Enable Phase 13 ingest (Google OAuth/IMAP mailbox) on backend staging | 2026-06-04 | (see PR feat/staging-ingest-oauth) | [260604-rec-enable-phase-13-ingest-google-oauth-imap](./quick/260604-rec-enable-phase-13-ingest-google-oauth-imap/) |
| 260622-dry | Staging-deploy readiness remediations (OIDC org→DM-Air, ingest SSM params, DeleteSecret, trip toggles, valkey doc, heap) — 3 live stacks verified No-changes | 2026-06-22 | (branch fix/staging-deploy-remediations) | [20260622-staging-deploy-remediations](./quick/20260622-staging-deploy-remediations/) |

### Risks Logged

- **EC2 `prevent_destroy = true`** on Strapi instance — any refactor must preserve the existing resource address (use `moved {}` blocks). Phase 2 risk.
- **No state locking today** — README mentions `terraform-state-lock` but no `backend.tf` declares any locking mechanism. Concurrent applies from two operators would corrupt state. Phase 1 closes this via S3-native `use_lockfile = true`.
- **Single shared AWS account** — OIDC role for dmair-backend CI (Phase 3) must be tag/prefix-scoped to deny existing `cms-*` / `frontend-*` resources. Verified by explicit deny-by-exclusion test.
- **Cross-repo contract:** `staging-api.flydmair.com` DNS name and OIDC role name are consumed by `dmair-backend`. Renaming them later is expensive.

### Lessons & Guardrails (backend/staging — learned 2026-06-04, Phase 13 enablement)

These three footgun classes each caused a live incident this session. Check them on **every** future change to `live/dmair/backend/staging`.

1. **No-tfvars default footgun.** CI (`plan-readonly`) and any `terraform apply -replace` run with **no** local `staging.auto.tfvars` (it is gitignored), so they fall back to the committed `default`s. A `default` that is a placeholder "only works because my local tfvars overrides it" is a landmine that silently ships a wrong value to a real apply. Hit **twice**: `staging_domain` defaulted to the dead `api-staging.flydmair.com` (fixed PR #12) and `app_image` defaulted to a bare `staging-latest` tag, not a pullable URI (fixed PR #15).
   - **Guardrail:** every `variables.tf` default for this stack MUST render a working value with zero tfvars. Before adding a var with a default, ask *"what does a CI/no-tfvars apply produce?"* Added a `validation` on `app_image` that rejects a bare tag. CI's green plan ≠ correct values — verify the **rendered** `user_data`/secret, not just that the plan is clean.

2. **Consolidated secret is rebuilt from SSM on every apply.** `dmair/staging/app` is `jsonencode`'d from `data.aws_ssm_parameter.*` (`secrets.tf`), so the `aws_secretsmanager_secret_version` is replaced from SSM on each apply and **any hand-edit to the secret is reverted**. The real SendGrid key lived only in the secret (SSM `/dmair/staging/mail_password` was a placeholder), so the Phase-13 apply clobbered it → SMTP 535, `/actuator/health` DOWN.
   - **Guardrail:** SSM Parameter Store is the source of truth — populate **every** `/dmair/staging/*` param with the real value; never patch the secret directly expecting it to persist. (Recovered the key from the secret's `AWSPREVIOUS` version and wrote it back to SSM.)

3. **`user_data` changes need `-replace`.** cloud-init runs once at first boot, so a plain `apply` updates the `user_data` attribute (a stop/start) but does **not** regenerate `/opt/dmair/docker-compose.staging.yml` — the change silently has no effect on the running app.
   - **Guardrail:** any user-data / compose change requires `terraform apply -replace=aws_instance.app`. For a **0-destroy hotfix**, SSM-patch the on-disk compose and re-run `start.sh` (recreates only the `app` container) — but still merge the code so a future rebuild keeps it.

## Session Continuity

**Resume point:** Run `/gsd-plan-phase 1` to decompose Phase 1 into plans.
**Last action:** Roadmap created and validated (100% v1 coverage).
**Next milestone:** Phase 1 complete — bootstrap stack applied, `use_lockfile = true` wired into all three existing `backend.tf` files, zero-change plans verified.

---
*State initialized: 2026-05-20*
