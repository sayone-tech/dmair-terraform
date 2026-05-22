# Phase 4 — DevOps Handoff

**Date:** 2026-05-21
**Branch:** `feature/aws-deployment`
**Scope:** PR-gated `terraform plan` (matrix per stack, posts plan as PR comment, blocks merge until plan succeeds). Manual `workflow_dispatch` apply per stack; staging dispatches run without a reviewer gate; prod dispatches pause on the `prod` GitHub Environment for reviewer approval.

**Prerequisites:**
- Phases 1, 2, 3 applied (or applied in lockstep with Phase 4).
- AWS account access with permissions to create IAM identity providers, IAM roles, and IAM inline policies.

---

## What this phase delivers

| Deliverable | File(s) |
|---|---|
| 4 OIDC-trusted IAM role JSON templates | `docs/iam-oidc/*.json` (8 files: 4 trust + 4 permissions) |
| Setup walkthrough | `docs/iam-oidc/README.md` |
| GitHub Actions workflow | `.github/workflows/terraform.yml` |

---

## Sequence to apply

### Step 1 — Create the OIDC IDP + IAM roles

Follow [`docs/iam-oidc/README.md`](../../../docs/iam-oidc/README.md) end-to-end. In short:

1. `aws iam create-open-id-connect-provider` (once per AWS account).
2. Locally substitute `ACCOUNT_ID`, `ORG/REPO`, `BACKEND_ORG/BACKEND_REPO`, `STAGING_EC2_INSTANCE_ID` into the 8 JSON templates (`sed` recipe in the README).
3. Run `aws iam create-role` + `aws iam put-role-policy` for each of the 4 roles.
4. **Do NOT** commit the rendered files — they contain the real account ID.

After Step 1 you have these 4 roles in AWS IAM:

- `dmair-terraform-plan-readonly`
- `dmair-terraform-staging-apply`
- `dmair-terraform-prod-apply`
- `dmair-backend-staging-deploy` (cross-repo; the dmair-backend repo's CI uses it)

### Step 2 — Configure the `prod` GitHub Environment

Settings → Environments → New environment → `prod`:

- **Required reviewers:** at least one specific GitHub user or team.
- **Deployment branches:** restrict to `main` only.

Without this Environment, the workflow's `apply-prod` job has nothing to gate on — apply would run without review.

### Step 3 — Add repository Secrets

Repo Settings → Secrets and variables → Actions → Repository secrets. Seven secrets total:

**Role ARNs (3) — from the manually-created roles in Step 1:**

| Secret | Value |
|---|---|
| `AWS_PLAN_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-plan-readonly` |
| `AWS_STAGING_APPLY_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-staging-apply` |
| `AWS_PROD_APPLY_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-prod-apply` |

**Application sensitive vars (4) — same values used in Phase 3 `staging.auto.tfvars`:**

| Secret | Source |
|---|---|
| `STAGING_BACKEND_DB_PASSWORD` | Phase 3 step 1 `staging.auto.tfvars` |
| `STAGING_BACKEND_JWT_SECRET` | same |
| `STAGING_BACKEND_MAIL_PASSWORD` | same |
| `STAGING_BACKEND_ADMIN_PASSWORD` | same |

Without the role ARNs the workflow's `configure-aws-credentials` step fails. Without the four app secrets, `terraform plan` against the staging-backend stack fails with `Error: No value for required variable`.

### Step 4 — Enable branch protection on `main`

Settings → Branches → Branch protection rules → `main`:

- Tick **Require status checks to pass before merging**
- Add `terraform / plan (...)` (matrix variants) as required checks.

This enforces CICD-01 #1's "merge is blocked until plan succeeds" requirement.

### Step 5 — Smoke test — PR plan

Open a no-op PR touching a single stack (e.g., add a comment line to `live/dmair/frontend/prod/main.tf`).

- `detect-changes` + `plan` jobs run.
- `apply-*` jobs do NOT run.
- A PR comment titled `### terraform plan — live/dmair/frontend/prod` appears.
- Merge button is blocked until the plan job succeeds.

Close the PR without merging.

### Step 6 — Smoke test — manual apply (staging)

Merge a staging-only PR (e.g., touching `live/dmair/frontend/staging/main.tf`).

- The post-merge `plan` job runs against `main` and uploads the plan artifact.
- Apply does NOT auto-run.

Now manually dispatch the apply:

- Actions → `terraform` workflow → **Run workflow** → pick the staging stack → Run.
- `apply-staging` runs to completion, with NO reviewer prompt.

### Step 7 — Smoke test — manual apply (prod, the load-bearing test)

Merge a prod-affecting PR (e.g., touching `live/dmair/strapi/prod/output.tf`).

- Post-merge `plan` job runs and uploads the plan artifact.
- Apply does NOT auto-run.

Dispatch:

- Actions → `terraform` → **Run workflow** → pick `live/dmair/strapi/prod` → Run.
- `apply-prod` pauses on the `prod` Environment. Actions UI shows "Review pending deployment".
- A listed reviewer clicks **Approve and deploy**.
- `apply-prod` resumes, assumes the `dmair-terraform-prod-apply` role, runs `terraform plan` + `apply`, exits clean.

### Step 8 — Smoke test — no-escalation invariant

This proves CICD-02 #3. Open a PR adding an out-of-scope IAM role, e.g.:

```hcl
# in live/dmair/strapi/prod/main.tf — DO NOT MERGE; this is a probe.
resource "aws_iam_role" "escalation_probe" {
  name = "not-in-scope-escalation-probe"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [] })
}
```

Plan succeeds. Merge to main, then **manually dispatch** `apply-prod` against `live/dmair/strapi/prod`. Reviewer approves, role assumes, terraform tries to create the role. Expected: `AccessDenied: iam:CreateRole` because `not-in-scope-*` doesn't match any prefix in `dmair-terraform-prod-apply`'s policy.

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

# 2. Delete the IAM roles via the AWS CLI (use the role names from docs/iam-oidc/README.md).
for role in dmair-terraform-plan-readonly \
            dmair-terraform-staging-apply \
            dmair-terraform-prod-apply \
            dmair-backend-staging-deploy; do
  aws iam delete-role-policy --role-name "$role" --policy-name "$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames[0]' --output text)"
  aws iam delete-role --role-name "$role"
done

# 3. Optionally remove the OIDC identity provider (only if no other roles trust it).
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
```

Once the roles are deleted, the corresponding GitHub Secrets become inert — workflows referencing them fail at the `configure-aws-credentials` step with `AccessDenied`, which is the desired behaviour.

---

## What this phase does NOT do

- **No Terraform management of OIDC roles.** All four OIDC-trusted IAM roles + the GitHub Actions OIDC identity provider are created out-of-band via the AWS CLI per `docs/iam-oidc/README.md`. This is a deliberate choice — see the README §Design notes.
- **No `dmair-backend` CI workflow.** That repo's `.github/workflows/deploy-staging.yml` is their responsibility; this phase just delivers the IAM role they assume (`dmair-backend-staging-deploy`).
- **No `checkov` / `tfsec` scan in the plan job.** User-confirmed out-of-scope for this milestone.
- **No automation for branch protection rules.** GitHub doesn't expose a clean Terraform-managed pathway for branch-protection-with-required-checks; this is a one-time manual UI step (Step 4).
