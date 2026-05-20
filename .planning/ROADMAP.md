# Roadmap: dmair-terraform

**Created:** 2026-05-20
**Granularity:** coarse
**Mode:** mvp
**Core Value:** Live infra is sacred — `terraform plan` on every existing live stack (`strapi`, `frontend/prod`, `frontend/staging`) must report "No changes" after every refactor commit. The dmair-backend staging slot is delivered on top of that invariant, not at the cost of it.

## Phases

- [ ] **Phase 1: Bootstrap State Backend** - Self-describing state backend + S3-native state locking wired into every existing stack (zero-change-plan gated)
- [ ] **Phase 2: Refactor to live/ Layout** - `envs/<x>` → `live/dmair/<env>/<component>` via `moved {}` blocks, README updated, staging slot reserved
- [ ] **Phase 3: dmair-backend Staging Slot** - `live/dmair/staging/backend/` stack with EC2 + Elastic IP + DNS + tag/prefix-scoped OIDC role
- [ ] **Phase 4: CI/CD Pipeline + OIDC** - PR-gated Lint + Plan; merge-gated Apply per stack via GitHub Environments; OIDC trust provider + role inventory in `OIDC.md`

## Phase Details

### Phase 1: Bootstrap State Backend
**Goal:** State backend is self-describing IaC and concurrent-apply-safe; every existing stack writes through S3-native state locking (use_lockfile = true) without changing any managed resource.
**Mode:** mvp
**Depends on:** Nothing (first phase)
**Requirements:** BOOTSTRAP-01, BOOTSTRAP-02, BOOTSTRAP-03
**Success Criteria** (what must be TRUE):
  1. `terraform plan` in `bootstrap/` reports "No changes" after the `dmair-terraform-prod` bucket is imported and `use_lockfile = true` is set on the bootstrap backend (operator verifies: `cd bootstrap && terraform plan` prints `No changes. Your infrastructure matches the configuration.`). The bootstrap stack creates no AWS resources — it is a pure import-only zero-change verification.
  2. `terraform plan` in each of `envs/strapi`, `envs/frontend/prod`, `envs/frontend/staging` reports "No changes" after `use_lockfile = true` is added to `backend.tf` and `terraform init -reconfigure` is run.
  3. Concurrent `terraform apply` from two terminals in the same stack blocks the second one on the S3 state lock: operator runs `terraform apply` in terminal A and immediately again in terminal B; terminal B prints `Acquiring state lock. This may take a few moments...` and waits until terminal A releases.
  4. During a held `terraform apply` against `envs/strapi`, `aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/` shows a `strapi/terraform.tfstate.tflock` sentinel object. After the apply prompt is answered (or Ctrl-C), the `.tflock` object disappears within seconds (operator verifies: re-run `aws s3 ls` and observe the object is gone).
**Plans:** 6 plans
  - [ ] 01-01-PLAN.md — Operator preconditions + live-state capture (BOOTSTRAP-01 prerequisite)
  - [ ] 01-02-PLAN.md — Create bootstrap/ stack, import bucket, enable use_lockfile on bootstrap backend, zero-change verify (BOOTSTRAP-01)
  - [ ] 01-03-PLAN.md — Rewire envs/strapi/backend.tf (BOOTSTRAP-02, 1/3)
  - [ ] 01-04-PLAN.md — Rewire envs/frontend/prod/backend.tf (BOOTSTRAP-02, 2/3)
  - [ ] 01-05-PLAN.md — Rewire envs/frontend/staging/backend.tf (BOOTSTRAP-02, 3/3)
  - [ ] 01-06-PLAN.md — Two-terminal concurrent-lock verification + .tflock object inspection + VERIFICATION.md (BOOTSTRAP-03)

### Phase 2: Refactor to live/ Layout
**Goal:** Folder layout is migrated to `live/dmair/<env>/<component>`, all three existing live stacks still plan clean, the staging backend slot directory exists, and the README reflects the new reality.
**Mode:** mvp
**Depends on:** Phase 1 (locking must be in place before multi-stack folder work)
**Requirements:** REFACTOR-01, REFACTOR-02, REFACTOR-03, DOCS-01
**Success Criteria** (what must be TRUE):
  1. Directory tree shows `live/dmair/prod/strapi/`, `live/dmair/prod/frontend/`, `live/dmair/staging/frontend/`, and `live/dmair/staging/` exists (operator verifies: `find live -type d` lists the four paths and `envs/` no longer contains the moved stacks).
  2. `terraform plan` in `live/dmair/prod/strapi`, `live/dmair/prod/frontend`, and `live/dmair/staging/frontend` each report "No changes" — every moved resource is covered by a `moved {}` block. This is the hard gate; any non-empty plan diff fails the phase.
  3. State keys at `s3://dmair-terraform-prod/strapi/terraform.tfstate`, `s3://dmair-terraform-prod/frontend/prod/terraform.tfstate`, `s3://dmair-terraform-prod/frontend/staging/terraform.tfstate` are unchanged (operator verifies: `aws s3 ls s3://dmair-terraform-prod/ --recursive` shows the same three keys at the same paths).
  4. `live/dmair/staging/` directory exists with at minimum a placeholder README, reserved for the dmair-backend slot.
  5. `README.md` describes the new `live/<project>/<env>/<component>` layout, the `bootstrap/` stack, and S3-native state locking (use_lockfile = true); the legacy "company-website production stack" framing is gone and the three live stacks (strapi CMS, frontend prod, frontend staging) are each named explicitly.
**Plans:** TBD

### Phase 3: dmair-backend Staging Slot
**Goal:** A dmair-backend staging stack is deployable into `live/dmair/staging/backend/` under `api-staging.flydmair.com`, and the GitHub OIDC role that drives it can only touch staging-scoped resources — not CMS or frontend.
**Mode:** mvp
**Depends on:** Phase 2 (the `live/dmair/staging/` slot must exist)
**Requirements:** STAGING-01, STAGING-02, STAGING-03
**Success Criteria** (what must be TRUE):
  1. `terraform apply` in `live/dmair/staging/backend/` provisions the full staging stack per STAGING-01 (VPC + 2 public subnets + IGW, EC2 `t4g.medium` + Elastic IP, EC2 instance role, security groups, RDS `db.t4g.micro` + PostGIS, ECR repo, consolidated Secrets Manager secret, CloudWatch log group, AWS Budget alarm) and exits 0; a follow-up `terraform plan` in the same directory reports "No changes".
  2. Existing live stacks remain untouched: `terraform plan` in `live/dmair/prod/strapi`, `live/dmair/prod/frontend`, and `live/dmair/staging/frontend` each still report "No changes" after the staging backend is applied.
  3. `dig +short api-staging.flydmair.com` resolves to the staging backend's Elastic IP address; `curl -sS https://api-staging.flydmair.com` returns a non-TLS-error response (cert acquirable from the EC2 host via Let's Encrypt / Caddy).
  4. The GitHub OIDC role for `dmair-backend` CI can read/write resources under `live/dmair/staging/*` (operator verifies: assume the role and `aws s3 ls` against the staging backend's bucket succeeds).
  5. Deny-by-exclusion verified: the same OIDC role, when used to attempt `aws s3api get-bucket-policy --bucket <cms-media-bucket>` or modify a `frontend-*` resource, is rejected with an `AccessDenied` / `not authorized` error. The role cannot reach existing `cms-*` / `frontend-*` resources in the shared `dmair` account.
**Plans:** TBD

### Phase 4: CI/CD Pipeline + OIDC
**Goal:** Every change to `dmair-terraform` flows through a PR-gated, reviewer-approved automation path; no operator runs `terraform apply` from a laptop after Phase 4 ships.
**Mode:** mvp
**Depends on:** Phase 3 (staging slot must exist before it can be a pipeline target)
**Requirements:** CICD-01, CICD-02
**Success Criteria** (what must be TRUE):
  1. A PR to `main` that touches any `live/*` stack triggers `terraform.yml` Lint + Plan; the plan output is posted as a PR comment and the merge is blocked until plan succeeds.
  2. A merge to `main` triggers a GitHub-Environments-gated `terraform apply` for each affected stack; required reviewers must approve before apply runs.
  3. The OIDC role used by the terraform pipeline can read/write resources under `live/dmair/staging/*` and the existing prod stacks per their stack-environment, and cannot escalate (no `iam:Create*` on roles it does not already own).
  4. `OIDC.md` documents the OIDC trust provider, the per-repo role ARNs (terraform-repo role + dmair-backend deploy role), and the assumed-role tag/prefix scoping rules.
**Plans:** TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Bootstrap State Backend | 0/6 | Planned | - |
| 2. Refactor to live/ Layout | 0/0 | Not started | - |
| 3. dmair-backend Staging Slot | 0/0 | Not started | - |
| 4. CI/CD Pipeline + OIDC | 0/0 | Not started | - |

## Coverage

**v1 requirements:** 12 total, 12 mapped, 0 unmapped.

| Requirement | Phase |
|-------------|-------|
| BOOTSTRAP-01 | Phase 1 |
| BOOTSTRAP-02 | Phase 1 |
| BOOTSTRAP-03 | Phase 1 |
| REFACTOR-01 | Phase 2 |
| REFACTOR-02 | Phase 2 |
| REFACTOR-03 | Phase 2 |
| DOCS-01 | Phase 2 |
| STAGING-01 | Phase 3 |
| STAGING-02 | Phase 3 |
| STAGING-03 | Phase 3 |
| CICD-01 | Phase 4 |
| CICD-02 | Phase 4 |

## Notes

- **Phase ordering is dictated by safety, not by feature value.** Bootstrap precedes refactor because doing multi-stack folder work without a lock table risks state corruption. Refactor precedes staging because the staging slot lives in a path that doesn't exist until the rename lands.
- **DOCS-01 folds into Phase 2** rather than getting its own phase. The README must reflect new layout at the same commit the layout changes; splitting them would leave the docs lying.
- **Zero-change-plan is the gate, not a goal.** Phases 1 and 2 are not considered done until every existing live stack plans clean. Phase 3 inherits the same invariant for the three pre-existing stacks.
- **State keys stay at current paths.** Folder names move under `live/`, but `s3://dmair-terraform-prod/strapi/`, `frontend/prod/`, `frontend/staging/` state keys do not relocate. Bucket layout drift is accepted; per-stack `terraform state mv` migrations are tracked as v2 STATE-01.
- **Coarse granularity, 3 phases.** Each delivers a verifiable end-state; combining further would couple bootstrap risk with refactor risk; splitting further would create artificial milestones (e.g. a "docs" phase) without independent verification value.

---
*Roadmap created: 2026-05-20*
