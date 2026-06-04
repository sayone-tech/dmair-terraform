# dmair-terraform

## What This Is

AWS infrastructure-as-code repo (Terraform + HCL) that owns the live deployment of the
`flydmair.com` product surface: a Strapi CMS on EC2, the marketing/SPA frontend
(`www.flydmair.com`, `flydmair.com`), and a staging frontend (`staging.flydmair.com`).
This GSD milestone takes the repo from "envs/-style scratchpad" to a project-keyed
`live/<project>/<component>/<env>` layout and adds a real state backend, so that the
sibling repo `dmair-backend` can land a staging deployment slot underneath the same
account.

## Core Value

**Live infra is sacred.** After every change, `terraform plan` on every existing live
stack (`strapi`, `frontend/prod`, `frontend/staging`) must report **"No changes"** —
the refactor cannot perturb running production. The dmair-backend staging slot is
delivered on top of that invariant, not at the cost of it.

## Requirements

### Validated

<!-- Inferred from existing code (codebase map 2026-05-20). These already work in prod. -->

- ✓ **Strapi CMS** on EC2 `t3.small` (Ubuntu 22.04) + Elastic IP + Dockerized MySQL,
  ECR repo, S3 + CloudFront media bucket, Secrets Manager — `cms.flydmair.com`,
  `strapi-cdn.flydmair.com` — existing
- ✓ **Frontend prod** S3 + CloudFront with URL-rewriting CloudFront Function —
  `www.flydmair.com`, `flydmair.com` — existing
- ✓ **Frontend staging** S3 + CloudFront with basic-auth + URL-rewriting CloudFront
  Functions — `staging.flydmair.com` — existing
- ✓ **11 reusable modules** (`ec2`, `ecr`, `eip`, `iam-policy`, `iam-role`,
  `iam-user`, `s3`, `secrets_manager`, `sg`, `cloudfront`, `cloudfront-function`) —
  existing
- ✓ **S3 remote state backend** at bucket `dmair-terraform-prod` in `us-west-2` (no
  locking) — existing, partial

### Active

**Phase 9 — Refactor + State Backend (this milestone):**

- [ ] **REFACTOR-01**: Layout migrated from `envs/<x>` to `live/dmair/<component>/<env>`
  via `moved {}` blocks. Folder names only — state keys stay at current paths
- [ ] **REFACTOR-02**: `terraform plan` on every existing live stack
  (strapi, frontend-prod, frontend-staging) reports "No changes" after the rename
- [ ] **BOOTSTRAP-01**: `bootstrap/` stack that `terraform import`s the existing
  `dmair-terraform-prod` bucket AND declares a new `dmair-terraform-locks` DynamoDB table
- [ ] **BOOTSTRAP-02**: Every existing backend.tf wired with `dynamodb_table = "dmair-terraform-locks"`;
  each stack `terraform init -reconfigure`'d; plans still zero-change
- [ ] **DOCS-01**: README + planning docs updated to reflect new layout, bootstrap stack,
  and remove the "company-website production stack" framing (it's three stacks, not one)

**dmair-backend staging slot:**

- [ ] **STAGING-01**: `live/dmair/backend/staging/` directory provisioned (Caddy-fronted
  EC2 or equivalent per dmair-backend Phase 9 plan) targeting `staging-api.flydmair.com`
- [ ] **STAGING-02**: DNS A-record for `staging-api.flydmair.com` pointing at the
  staging backend's Elastic IP; ACM/Let's Encrypt cert acquirable
- [ ] **STAGING-03**: GitHub OIDC role + tag/prefix-scoped IAM policy that lets
  `dmair-backend` CI deploy into `live/dmair/staging/*` without being able to touch
  existing `cms-*`/`frontend-*` resources in the shared account

**CI/CD pipeline (this milestone):**

- [ ] **CICD-01**: `.github/workflows/terraform.yml` — PR-gated Lint + Plan; merge-gated Apply per-stack via GitHub Environments
- [ ] **CICD-02**: OIDC trust provider + per-repo per-stack roles, documented in `OIDC.md` for cross-repo consumption

### Out of Scope

- **`us-east-1` region or a separate AWS account for dmair-backend** — chose
  shared single-account `us-west-2` for simplicity + state-bucket reuse. Revisit only
  if blast-radius isolation becomes a real requirement
- **Migrating `staging.flydmair.com` to a different name** — frontend staging keeps
  the existing DNS; backend gets the new `staging-api.flydmair.com` name instead.
  Touching live frontend DNS is unnecessary risk
- **Relocating state keys** to match new folder layout — folder names move, state
  keys at `strapi/terraform.tfstate`, `frontend/staging/terraform.tfstate`,
  `frontend/prod/terraform.tfstate` stay put. Avoids per-stack `terraform state mv`
  migrations; the cost is state-bucket layout drifts from folder layout
- **`terratest` / `checkov` / `tfsec` introduction** — out of this milestone. Quality
  gating is the zero-change-plan invariant for now
- **Production deployment slot for dmair-backend** — staging only. Prod slot comes
  in a later milestone after staging proves out

## Context

- **Brownfield:** repo has lived for a while. Codebase map at `.planning/codebase/`
  (analysis date 2026-05-20) captures STACK, STRUCTURE, ARCHITECTURE, CONCERNS,
  CONVENTIONS, INTEGRATIONS, TESTING
- **Cross-repo origin:** Phase 9 was specified in the sibling repo `dmair-backend`
  (`.planning/ROADMAP.md` Phase 9 + `deployment/staging/STAGING-DEPLOYMENT.md`).
  The seed at `.planning/seeds/phase-09-context.md` documents six concrete
  reality-vs-plan conflicts and how this project resolves them
- **EC2 `lifecycle { prevent_destroy = true }`** is set on the Strapi instance — a
  destroy/recreate is impossible without removing that block; any refactor must
  preserve the existing resource address or use `moved {}` blocks
- **No state locking today.** README mentions `terraform-state-lock` but no backend.tf
  references a DynamoDB table — concurrent `terraform apply` from two operators would
  corrupt state. Fixing this is part of Phase 9
- **Single shared AWS account** ("dmair" profile) for all three live stacks plus the
  incoming backend staging slot. OIDC scoping has to keep dmair-backend CI from
  reaching CMS/frontend resources
- **Team:** primary engineer + 1–2 collaborators. Branch hygiene matters; PRs welcome
  but not gated

## Cross-Repo Phase Mapping

This milestone implements work that the sibling repo `bere-creator/dmair-backend`
specifies in its v1.3 ROADMAP (Phases 8–11). The two repos use independent phase
numbering. Mapping:

| `dmair-backend` phase | `dmair-terraform` phase(s) | Notes |
|-----------------------|---------------------------|-------|
| Phase 8 (Backend Deployment Readiness) | n/a — app-side only | Shipped 2026-05-19. No terraform work. |
| Phase 9 (Terraform Refactor + State Backend) | Phase 1 (Bootstrap) + Phase 2 (Refactor) | Split across two phases here to isolate bootstrap-state risk from rename risk. |
| Phase 10 (Staging Infrastructure Stack) | Phase 3 (Staging Slot) | INFRA-* + CICD-02 policy (OIDC IAM) live here; ART-* (compose, Caddyfile, image build) live in dmair-backend. |
| Phase 11 (CI/CD Pipelines + Go-Live) | Phase 4 (CI/CD Pipeline + OIDC) — partial | CICD-01 (terraform.yml) lives here; ART-03 (deploy-staging.yml), OPS-01/02 (verification), OPS-03 (SRE runbook) live in dmair-backend. |

Cross-repo contracts (renaming any of these is expensive):

- DNS name: `staging-api.flydmair.com` (terraform repo provisions/registers; dmair-backend Caddy claims certs against it)
- OIDC role for `dmair-backend` CI: name + ARN documented in `OIDC.md` (Phase 4), consumed by `dmair-backend/.github/workflows/deploy-staging.yml`
- ECR repository name + URI: output by Phase 3 staging stack, consumed by the dmair-backend image push step
- Consolidated Secrets Manager secret name: output by Phase 3, consumed by the dmair-backend EC2 user-data launcher

Coordination expectation: when any of the above contracts changes here, post the
change in `dmair-backend` and update `deployment/staging/STAGING-DEPLOYMENT.md` in
the same PR cycle.

## Constraints

- **Tech stack:** Terraform CLI ≥ 1.0, `hashicorp/aws` provider pinned at `5.91.0`,
  HCL only — no Terraform Registry modules, all module sources are local `../../modules/...`
- **Region:** `us-west-2` for all stacks (existing + new staging). Hard constraint —
  changing regions would require destroying EC2 with `prevent_destroy = true`
- **AWS account:** single account, profile `dmair` for local; OIDC for CI
- **Live infra invariant:** zero-change plans on strapi / frontend-prod / frontend-staging
  after every Phase 9 commit. This is the gate, not the goal
- **No managed test suite** — quality comes from `terraform plan` diffs reviewed by
  humans, plus the zero-change invariant. Introducing tooling is out of scope this milestone
- **Cross-repo coordination:** `staging-api.flydmair.com` DNS + OIDC role names are
  contracts the `dmair-backend` repo will consume. Renaming them later is expensive

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Region: `us-west-2` for new backend staging | Share account + state bucket with existing stacks; EC2 `prevent_destroy = true` blocks a region migration anyway | — Pending |
| Backend staging DNS: `staging-api.flydmair.com` | `staging.flydmair.com` already pinned to frontend CloudFront; rename backend (cheap) instead of migrating frontend DNS (risky) | — Pending |
| Layout: `live/dmair/<component>/<env>` | Project-keyed under the `dmair` umbrella matches the existing AWS profile name and the seed's reserved `live/dmair/staging` slot | — Pending |
| Account topology: single shared AWS account | Existing reality; isolation deferred until there's a concrete need. Requires careful OIDC scoping for dmair-backend CI | — Pending |
| Full bootstrap stack (import bucket + add lock table) | State backend becomes self-describing IaC; the lock table closes a real concurrent-apply hole | — Pending |
| Keep state keys at current paths during folder rename | Avoids per-stack `terraform state mv` migrations. Cost: state-bucket layout drifts from folder layout (acceptable) | — Pending |
| Core value: zero-change plan on every existing live stack | Live infra is sacred; staging slot is delivered on top of that invariant, not at the cost of it | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-20 after initialization*
