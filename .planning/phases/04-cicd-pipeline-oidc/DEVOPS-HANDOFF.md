# Phase 4 — DevOps Handoff

**Date:** 2026-05-21
**Branch:** `feature/aws-deployment`
**Scope:** Land the dmair-terraform CI/CD pipeline. PR-gated `terraform plan` (matrix per stack, posts plan as PR comment, blocks merge until plan succeeds). Merge-gated `terraform apply` — staging auto-applies; prod paused by the `prod` GitHub Environment for reviewer approval.

**Prerequisite:** Phases 1, 2, 3 must be DevOps-applied first. Phase 4 references the OIDC provider created in Phase 3; without that, the `ci/` stack's `data` source fails.

---

## What this phase delivers

| Deliverable | File(s) |
|---|---|
| 3 OIDC-trusted IAM roles | `ci/` stack — backend.tf / providers.tf / variables.tf / main.tf / outputs.tf |
| GitHub Actions workflow | `.github/workflows/terraform.yml` |
| Trust + role inventory docs | `OIDC.md` at repo root |
| Phase docs | `.planning/phases/04-cicd-pipeline-oidc/` |

---

## Sequence to apply

### Step 1 — Apply `ci/` (one-time bootstrap)

This **must** be done manually by an operator with full IAM perms (the workflow itself can't apply `ci/` — the roles need to exist before they can be assumed).

```sh
cd ci
terraform init
terraform plan     # expect ~5 to add (3 roles, 3 inline policies, 0 destroy)
terraform apply
terraform output   # capture the three role ARNs
```

If the account ID in `.github/workflows/terraform.yml` env block (currently hardcoded `071297531943`) doesn't match your `data.aws_caller_identity.current.account_id`, fix the workflow before merging — or rewrite the role-arn env vars to reference `${{ secrets.AWS_ACCOUNT_ID }}` and add a repo Secret. We hard-coded for the dmair account; if you change accounts later, parameterize.

### Step 2 — Configure GitHub Environment `prod`

Repo Settings → Environments → New environment → `prod`:

- **Required reviewers:** add at least one specific GitHub user or team.
- **Deployment branches:** restrict to `main` only.

Without this Environment, the `apply-prod` workflow job has nothing to gate on — apply runs without review. Don't skip this step.

### Step 3 — Add repository Secrets

Repo Settings → Secrets and variables → Actions → Repository secrets. Seven secrets total:

**Role ARNs (3) — from `cd ci && terraform output` in Step 1:**

| Secret | Source | Used by |
|---|---|---|
| `AWS_PLAN_ROLE_ARN` | `terraform output plan_readonly_role_arn` | plan job |
| `AWS_STAGING_APPLY_ROLE_ARN` | `terraform output staging_apply_role_arn` | apply-staging job |
| `AWS_PROD_APPLY_ROLE_ARN` | `terraform output prod_apply_role_arn` | apply-prod job |

**Application sensitive vars (4) — same values used in Phase 3 `staging.auto.tfvars`:**

| Secret | Source | Used by |
|---|---|---|
| `STAGING_BACKEND_DB_PASSWORD` | Phase 3 step 1 `staging.auto.tfvars` | plan + apply-staging |
| `STAGING_BACKEND_JWT_SECRET` | same | plan + apply-staging |
| `STAGING_BACKEND_MAIL_PASSWORD` | same | plan + apply-staging |
| `STAGING_BACKEND_ADMIN_PASSWORD` | same | plan + apply-staging |

Without the role ARNs, the workflow's `configure-aws-credentials` step fails. Without the four app secrets, `terraform plan` against the staging-backend stack fails with `Error: No value for required variable`.

### Step 4 — Enable branch protection on `main`

Settings → Branches → Branch protection rules → `main`:

- Tick **Require status checks to pass before merging**
- Add `terraform / plan (...)` (the matrix variants) as required checks.

This enforces CICD-01 #1's "merge is blocked until plan succeeds" requirement. (The plan-comment behaviour and the workflow itself ship in this PR — the merge-gate is the GitHub-UI step that activates it.)

### Step 5 — Smoke test — PR plan

Open a no-op PR touching a single stack (e.g., add a comment line to `live/dmair/prod/frontend/main.tf`).

- `detect-changes` + `plan` jobs run.
- `apply-*` jobs do NOT run.
- A PR comment titled `### terraform plan — live/dmair/prod/frontend` appears.
- Merge button is blocked until the plan job succeeds.

Close the PR without merging.

### Step 6 — Smoke test — manual apply (staging)

Merge a staging-only PR (e.g., touching `live/dmair/staging/frontend/main.tf`).

- The post-merge `plan` job runs against `main` and uploads the plan artifact for review.
- Apply does NOT auto-run.

Now manually dispatch the apply:

- Actions → `terraform` workflow → **Run workflow** → pick the staging stack → Run.
- `apply-staging` runs to completion, with NO reviewer prompt.

### Step 7 — Smoke test — manual apply (prod, the load-bearing test)

Merge a prod-affecting PR (e.g., touching `live/dmair/prod/strapi/output.tf`).

- Post-merge `plan` job runs and uploads the plan artifact.
- Apply does NOT auto-run.

Dispatch:

- Actions → `terraform` → **Run workflow** → pick `live/dmair/prod/strapi` → Run.
- `apply-prod` pauses on the `prod` Environment. Actions UI shows "Review pending deployment".
- A listed reviewer clicks **Approve and deploy**.
- `apply-prod` resumes, assumes the `dmair-terraform-prod-apply` role, runs `terraform plan` + `apply`, exits clean.

### Step 8 — Smoke test — no-escalation invariant

This proves CICD-02 #3. Open a PR adding an out-of-scope IAM role, e.g.:

```hcl
# in live/dmair/prod/strapi/main.tf — DO NOT MERGE; this is a probe.
resource "aws_iam_role" "escalation_probe" {
  name = "not-in-scope-escalation-probe"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [] })
}
```

Plan succeeds. Merge to main, then **manually dispatch** `apply-prod` against `live/dmair/prod/strapi` (so reviewer approves, role assumes, then terraform tries to create the role). Expected: `AccessDenied: iam:CreateRole` because `not-in-scope-*` doesn't match any prefix in `dmair-terraform-prod-apply`'s policy.

Revert the probe commit. The failure log is the evidence — paste it into VERIFICATION.md.

### Step 9 — Fill VERIFICATION.md + commit

Open [`VERIFICATION.md`](./VERIFICATION.md). Fill in evidence for each section. Tick both Phase Exit checkboxes. Set Outcome = PASS. Commit:

```
docs(CICD-02): record CI/CD pipeline verification evidence
```

Then `/gsd-transition` to mark the milestone complete.

---

## Rollback

To roll back Phase 4:

```sh
# 1. Revert the workflow first so CI stops trying to run.
git revert <workflow commit sha>
git push

# 2. Destroy the ci/ stack.
cd ci
terraform destroy
```

Note that destroying `ci/` removes the three roles — any in-flight Actions runs that were mid-OIDC-assume will error out. Coordinate with the team if there are pending PRs.

The OIDC provider in `live/dmair/staging/backend/oidc.tf` stays in place during a Phase 4 rollback — it's still consumed by `dmair-backend-staging-deploy`.

---

## What this phase does NOT do

- **No changes to OIDC provider location.** Still in `live/dmair/staging/backend/oidc.tf`. Future improvement: `terraform state mv` into `ci/`. See `OIDC.md` §Future improvements.
- **No `dmair-backend` CI workflow.** That repo's `.github/workflows/deploy-staging.yml` is their responsibility; this phase just delivers the IAM role they assume (`dmair-backend-staging-deploy`, from Phase 3).
- **No `checkov` / `tfsec` scan in the plan job.** User-confirmed out-of-scope for this milestone.
- **No automation for branch protection rules.** GitHub doesn't expose a clean Terraform-managed pathway for branch-protection-with-required-checks; this is a one-time manual UI step (Step 4).
