# PR: Phase 1–4 — State backend, live/ refactor, dmair-backend staging slot, CI/CD + OIDC

**Branch:** `feature/aws-deployment` → `main`
**Scope:** all four phases of the v1.0 `dmair-terraform` milestone, shipped as **code-only**. No AWS-side `terraform apply` has been run from this branch. Every gate (zero-change plans, lock-contention proof, deny-by-exclusion, CI smoke tests) is deferred to DevOps post-review.

**Stats:** 25 commits · 80 files · +4,556 / −343 lines.

---

## What's in this PR

### Phase 1 — Bootstrap State Backend
- `bootstrap/` greenfield stack: adopts the existing `dmair-terraform-prod` S3 bucket via 4 declarative `import {}` blocks (no creates). Includes `use_lockfile = true` on its own backend.
- Live-stack rewires: 6 atomic one-line commits — `use_lockfile = true` added to each of `live/dmair/prod/strapi/backend.tf`, `live/dmair/prod/frontend/backend.tf`, `live/dmair/staging/frontend/backend.tf`, and `required_version = "~> 1.15"` added to each `providers.tf`.
- DevOps runbook for the 8 `aws s3api` / `dynamodb` / `sts` captures; fillable `01-LIVE-STATE-SNAPSHOT.md` template with `TODO_DEVOPS_FROM_SNAPSHOT` markers in `bootstrap/main.tf` for the literal values DevOps fills in.
- Fillable `VERIFICATION.md` for the two-terminal concurrent-apply `.tflock` evidence.

### Phase 2 — Refactor to `live/` Layout
- Three `git mv` atomic commits: `envs/strapi/` → `live/dmair/prod/strapi/`, `envs/frontend/prod/` → `live/dmair/prod/frontend/`, `envs/frontend/staging/` → `live/dmair/staging/frontend/`.
- Relative module paths bumped (`../../modules/` → `../../../../modules/`). State keys, module call labels, and AWS-managed resources unchanged — **no `moved {}` blocks needed**.
- `live/dmair/staging/README.md` reserves the slot for the dmair-backend stack (Phase 3).
- Root `README.md` full rewrite (336 → 163 lines): drops legacy "Runway One Aviation" framing, documents the new `live/<project>/<env>/<component>/` layout, the `bootstrap/` stack, `use_lockfile`, three named live stacks, operator quick-start, and conventions.

### Phase 3 — dmair-backend Staging Slot (`live/dmair/staging/backend/`)
13-file Terraform stack matching `dmair-backend/deployment/staging/STAGING-DEPLOYMENT.md` §10 field-for-field, with three repo-convention substitutions (`use_lockfile` instead of DynamoDB; `~> 1.15` instead of `>= 1.6`; `aws = "5.91.0"` instead of `~> 5.0`):
- **Networking:** dedicated VPC `10.0.0.0/16`, IGW, 2 public subnets across 2 AZs.
- **Compute:** EC2 `t4g.medium` ARM Graviton, Ubuntu 24.04 LTS ARM64 (Canonical SSM param), IMDSv2-only, 30 GB gp3 encrypted root, EIP with `prevent_destroy = true`.
- **Data:** RDS PostgreSQL 16 (`db.t4g.micro`, gp3 20 GB → 100 GB autoscale, Single-AZ, encrypted, 7-day backups, `publicly_accessible = false`). PostGIS extension applied by Flyway V6 at app boot — no Terraform step.
- **Containers infra:** ECR repo `dmair-backend` with lifecycle policy (keep last 30 tagged; expire untagged after 14d). Consolidated `dmair/staging/app` Secrets Manager secret (4 sensitive keys passed via `TF_VAR_*`). CloudWatch log group `/dmair/staging`, 5-day retention.
- **IAM:** EC2 instance role with scoped ECR/Secrets/Logs perms + AWS-managed `AmazonSSMManagedInstanceCore`. EC2 access is **SSM Session Manager only** — no port 22.
- **Cost guard:** AWS Budget monthly $60 cap, 80% threshold email to `ops@flydmair.com`, scoped to `Project=dmair` + `Environment=staging` tags.
- **OIDC:** GitHub Actions OIDC identity provider (account-wide) + `dmair-backend-staging-deploy` role with sub-claim restricted to staging-track refs and a deny-by-exclusion permission policy (ECR push/pull on `dmair-backend` only, Secrets read on `dmair/staging/app` only, SSM SendCommand/StartSession on the staging EC2 only).
- **EC2 user-data:** `user-data.sh` writes docker-compose + Caddyfile + secret-injecting launcher + systemd unit on first boot.
- **`staging.auto.tfvars.example`** template + `.gitignore` entry so DevOps can't accidentally commit secrets.

### Phase 4 — CI/CD Pipeline + OIDC
- **`ci/` stack** — new Terraform workspace at state key `ci/terraform.tfstate`. Three OIDC-trusted IAM roles:
  - `dmair-terraform-plan-readonly` — `Describe`/`Get`/`List` only across the whole account, plus state-bucket read + `.tflock` write. **No `secretsmanager:GetSecretValue`**, no mutations. Assumed on every PR and push to main.
  - `dmair-terraform-staging-apply` — scoped writes to `Environment=staging` tag / `dmair-staging-*` name prefix only. IAM `Create*` blocked outside the staging prefixes.
  - `dmair-terraform-prod-apply` — assumed only when the OIDC sub claim includes `environment:prod`. Broader prod-prefix scope (`strapi-*`, `frontend-*`, `dmair-prod-*`, `cms-*`, `github-actions-*`) — primary safety control is the `prod` GitHub Environment with required reviewers.
- **`.github/workflows/terraform.yml`** — single workflow with `detect-changes` → per-stack `plan` matrix → `apply-staging` (auto) + `apply-prod` (gated by `prod` Environment). Plan output posts as a PR comment. Path-filter routing; `modules/*` or `policies/*` changes fan out to every stack.
- **`OIDC.md`** at repo root — single source of truth for trust provider, all four OIDC role inventories (3 terraform CI + 1 cross-repo dmair-backend-staging-deploy), GitHub Environment config, repo Secrets table, sub-claim format reference, future-improvements.

---

## What's pending — DevOps (must apply in this order)

### Phase 1
- [ ] Add write-capable `[dmair]` profile to `~/.aws/credentials` (perms in `.planning/phases/01-bootstrap-state-backend/01-01-DEVOPS-RUNBOOK.md`).
- [ ] Run the 8 captures; populate `01-LIVE-STATE-SNAPSHOT.md`.
- [ ] Replace every `TODO_DEVOPS_FROM_SNAPSHOT` in `bootstrap/main.tf`.
- [ ] `cd bootstrap && terraform init && terraform apply` → expect `0 to add, 4 to import, 0 to change`.
- [ ] Zero-change re-plan; then a follow-up commit removing the four `import {}` blocks; re-verify zero-change.
- [ ] For each of the three live stacks: `terraform init -reconfigure && terraform plan` → **must report `No changes.`**
- [ ] Two-terminal concurrent-apply lock proof against the strapi stack; capture `aws s3 ls` `.tflock` evidence.
- [ ] Fill `.planning/phases/01-bootstrap-state-backend/VERIFICATION.md`; commit; `/gsd-transition`.

Per-phase walkthrough: [.planning/phases/01-bootstrap-state-backend/DEVOPS-HANDOFF.md](.planning/phases/01-bootstrap-state-backend/DEVOPS-HANDOFF.md)

### Phase 2
- [ ] For each moved stack: `rm -rf .terraform/ && terraform init -reconfigure && terraform plan` → **must report `No changes.`** (the hard gate).
- [ ] Bootstrap stack still plans clean.
- [ ] `aws s3 ls s3://dmair-terraform-prod/ --recursive` shows four state keys at unchanged paths.
- [ ] Fill `VERIFICATION.md`; `/gsd-transition`.

Per-phase walkthrough: [.planning/phases/02-refactor-to-live-layout/DEVOPS-HANDOFF.md](.planning/phases/02-refactor-to-live-layout/DEVOPS-HANDOFF.md)

### Phase 3
- [ ] Generate four sensitive values: `db_password`, `jwt_secret_key` (≥64 chars), `mail_password` (SendGrid API key), `admin_bootstrap_password`. Provide via `staging.auto.tfvars` (gitignored) or `TF_VAR_*`.
- [ ] `cd live/dmair/staging/backend && terraform init && terraform apply` (~10–15 min).
- [ ] Capture outputs (EIP, instance_id, ECR URL, OIDC role ARN).
- [ ] **GoDaddy:** add A record `api-staging.flydmair.com` → EIP. Must exist **before** Caddy's first ACME attempt.
- [ ] Build + push first ARM64 image (from `dmair-backend` repo) to the new ECR repo.
- [ ] SSM into EC2; `sudo systemctl restart dmair-staging.service`. Tail logs.
- [ ] Smoke test: `curl https://api-staging.flydmair.com/actuator/health`.
- [ ] Admin bootstrap (BLOCKED on `dmair-backend` §8.1(b) — see cross-repo below).
- [ ] **STAGING-03 deny-by-exclusion:** assume `dmair-backend-staging-deploy` role; confirm allows on staging ARNs + AccessDenied on `cms-*`/`frontend-*`/`strapi-*`.
- [ ] Fill `VERIFICATION.md`; `/gsd-transition`.

Per-phase walkthrough: [.planning/phases/03-dmair-backend-staging-slot/DEVOPS-HANDOFF.md](.planning/phases/03-dmair-backend-staging-slot/DEVOPS-HANDOFF.md)

### Phase 4
- [ ] **One-time bootstrap:** `cd ci && terraform apply` (the roles must exist before CI can assume them — chicken-and-egg).
- [ ] Repo **Settings → Environments → `prod`** with required reviewers, restricted to `main`.
- [ ] Add 4 repo Secrets: `STAGING_BACKEND_DB_PASSWORD`, `STAGING_BACKEND_JWT_SECRET`, `STAGING_BACKEND_MAIL_PASSWORD`, `STAGING_BACKEND_ADMIN_PASSWORD`.
- [ ] **Settings → Branches → main** → enable branch protection; require `terraform / plan (...)` status checks.
- [ ] Smoke test: open a no-op PR; confirm plan job posts a PR comment and the merge button is blocked.
- [ ] Smoke test: merge a staging-only change; confirm `apply-staging` auto-runs end-to-end.
- [ ] Smoke test: merge a prod-affecting change; confirm `apply-prod` pauses for reviewer approval, then applies cleanly.
- [ ] Smoke test (no-escalation invariant): try adding an IAM role outside the allowed name prefixes; confirm `apply-prod` fails with `AccessDenied: iam:CreateRole`.
- [ ] Fill `VERIFICATION.md`; `/gsd-transition`.

Per-phase walkthrough: [.planning/phases/04-cicd-pipeline-oidc/DEVOPS-HANDOFF.md](.planning/phases/04-cicd-pipeline-oidc/DEVOPS-HANDOFF.md)

---

## What's pending — Cross-repo (`dmair-backend`)

These do **not** block landing this PR but **do** block parts of the Phase 3 + Phase 4 verification:

- **§8.1(b) AdminBootstrapRunner** — implement create-or-activate mode reading `ADMIN_BOOTSTRAP_PASSWORD`. Without it, the staging admin uses the legacy activation-link fallback.
- **§8.1(a)** actuator hardening in `application-staging.properties`.
- **§8.1(c)** Dockerfile entrypoint forward `"$@"` so `--admin-bootstrap` reaches the JVM.
- **`.github/workflows/deploy-staging.yml`** in `dmair-backend` using the `dmair-backend-staging-deploy` role ARN (output by our Phase 3 apply).
- **`.github/workflows/quality-gate.yml`** in `dmair-backend`.

---

## Risk + safety

- **Live-infra-is-sacred invariant maintained.** No code in this PR adds, modifies, or destroys any pre-existing AWS resource. Phases 1 + 2 reorganize / configure Terraform state metadata only (`use_lockfile`, directory rename, relative paths). Phase 3 is purely additive (greenfield staging slot). Phase 4 adds new IAM roles in a new state.
- **Every commit is independently revertable.** Per-task atomic commits with D-13 discipline; backend.tf / providers.tf split across two commits per stack so a bad rewire can be undone in isolation.
- **No secrets in code.** Four sensitive vars (`db_password`, `jwt_secret_key`, `mail_password`, `admin_bootstrap_password`) flow via `TF_VAR_*` from GitHub Secrets / local `staging.auto.tfvars` (gitignored). The `.example` template is the only thing committed.
- **No-escalation invariant.** `dmair-terraform-staging-apply` and `dmair-terraform-prod-apply` IAM scopes block `iam:Create*` outside their respective name prefixes — see [OIDC.md](OIDC.md) for the per-role scope.

## Deferred to v2 (not in this PR)

- Move the OIDC identity provider from Phase 3's stack to `ci/` via `terraform state mv` (decouples account-wide trust from staging-backend lifecycle).
- Tag every prod resource `Environment=prod` so the prod-apply role can tighten to a single tag condition.
- Static security scan (`checkov` / `tfsec`) in the plan workflow.
- Parameterize the hardcoded account ID `071297531943` in `.github/workflows/terraform.yml`.

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
