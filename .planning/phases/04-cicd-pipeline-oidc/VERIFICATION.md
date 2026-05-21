# Phase 4: CI/CD Pipeline + OIDC — Verification Evidence

**Status:** TEMPLATE — pending DevOps execution.

**Date:** _(YYYY-MM-DD)_
**Verifier:** _(DevOps name)_
**Outcome:** _PASS / FAIL_

---

## Pre-verification — Apply `ci/`

The CI roles must exist before the workflow can assume them. This is a one-time bootstrap step run by an operator with full IAM perms (not via the workflow itself — circular dependency otherwise).

```sh
cd ci
terraform init
terraform plan        # expect ~5 resources to add (3 roles, 3 inline policies)
terraform apply       # answer yes
terraform output
```

```text
TODO_DEVOPS: paste `terraform output` showing the three role ARNs + the OIDC provider ARN.
```

Confirm the three role ARNs match the env vars in `.github/workflows/terraform.yml`:

- `PLAN_ROLE_ARN` should equal `terraform output plan_readonly_role_arn`
- `STAGING_APPLY_ROLE_ARN` should equal `terraform output staging_apply_role_arn`
- `PROD_APPLY_ROLE_ARN` should equal `terraform output prod_apply_role_arn`

If the account ID in the workflow's hardcoded ARNs (`071297531943`) doesn't match `data.aws_caller_identity.current.account_id`, fix the workflow env block first.

```text
TODO_DEVOPS: confirm three ARNs match the workflow env vars (or note discrepancies).
```

---

## Pre-verification — Configure GitHub Environments + Secrets

Settings → Environments → `prod`:
- Required reviewers: _(at least one)_
- Deployment branches: `main` only

Settings → Secrets and variables → Actions → Repository secrets:

| Secret | Set |
|---|---|
| `STAGING_BACKEND_DB_PASSWORD` | _( yes / no )_ |
| `STAGING_BACKEND_JWT_SECRET` | _( yes / no )_ |
| `STAGING_BACKEND_MAIL_PASSWORD` | _( yes / no )_ |
| `STAGING_BACKEND_ADMIN_PASSWORD` | _( yes / no )_ |

```text
TODO_DEVOPS: tick all four. Confirm `prod` Environment exists with reviewers.
```

---

## CICD-01 #1 — PR triggers `plan` + comment + merge gate

1. Open a no-op PR touching one stack (e.g., a comment in `live/dmair/prod/strapi/main.tf`).
2. Watch the workflow run. The `detect-changes` + `plan` jobs run; the two `apply-*` jobs are skipped (because `github.event_name == 'pull_request'`).
3. The `plan` job posts a comment on the PR.
4. The PR's "merge" button is disabled because `terraform / plan` is a required status check.

```text
TODO_DEVOPS: paste link to the PR (or screenshot the workflow + PR comment). Confirm:
  - plan job ran for the touched stack only
  - apply jobs did NOT run
  - PR comment posted with `terraform plan` output
  - merge button blocked
```

If the merge button isn't blocked: go to Settings → Branches → Branch protection rules → `main` → tick `Require status checks to pass before merging` and select the `terraform / plan` checks. This is a one-time GitHub-UI step; not codified in Terraform.

---

## CICD-01 #2 + CICD-02 #1 — Push to main → staging auto-applies + prod gated

Merge a staging-only change (e.g., touch `live/dmair/staging/frontend/main.tf` or `live/dmair/staging/backend/cloudwatch.tf`). Confirm:

- `detect-changes` → `plan` → `apply-staging` runs end-to-end without any reviewer interaction.
- `apply-prod` runs (because of the matrix) but its filter step short-circuits all subsequent steps (no work done).

```text
TODO_DEVOPS: paste workflow run link. Confirm apply-staging applied; apply-prod was a no-op via filter.
```

Now merge a prod-affecting change (e.g., touch `bootstrap/main.tf` or `live/dmair/prod/frontend/main.tf`). Confirm:

- `apply-prod` pauses on the `prod` Environment gate. The Actions run shows a "Review pending deployment" prompt.
- An approved reviewer clicks "Approve and deploy". The job resumes.
- `apply-prod` succeeds with the prod-apply role assumed.

```text
TODO_DEVOPS: paste workflow run link showing the reviewer-gate prompt + post-approval apply success.
```

---

## CICD-02 #3 — No-escalation invariant

Attempt to add an IAM role that escapes the scoped name prefixes — e.g., a role named `not-in-scope-attacker-role` in `live/dmair/prod/strapi/main.tf`. Push to a branch, open PR:

- `plan` job should succeed (plan is permissive — it can plan a role create).
- Merge to main → `apply-prod` is invoked with reviewer approval. After approval, the apply should FAIL with an `AccessDenied` on `iam:CreateRole` because the role name doesn't match the prefix list in `dmair-terraform-prod-apply`'s policy.

Revert the test change after the failure.

```text
TODO_DEVOPS: paste the AccessDenied error from the failing apply. This is the no-escalation evidence.
```

(Alternative test: try to add a role under the staging-apply role's scope but with a name outside its prefix. Same expected failure.)

---

## CICD-02 #4 — OIDC.md complete

Spot-check that [`OIDC.md`](../../../OIDC.md) at repo root contains:

- [ ] OIDC trust provider details (URL, audience, thumbprint, where it's defined)
- [ ] All four OIDC-trusted role inventories (plan-readonly, staging-apply, prod-apply, dmair-backend-staging-deploy) with sub-claim trust, scope, and where each is defined
- [ ] GitHub Environments configuration guide (`prod` + optional `staging`)
- [ ] Repository Secrets table
- [ ] Trust subject claim reference table
- [ ] Future-improvements section

```text
TODO_DEVOPS: tick each box or note specific gaps.
```

---

## Phase Exit

- [ ] **CICD-01** — PR triggers plan + PR comment + merge-gate; staging auto-applies; prod gated by `prod` Environment with reviewers
- [ ] **CICD-02** — All four OIDC roles enumerated in OIDC.md; no-escalation invariant enforced (apply fails for IAM names outside the role's prefix list)

Set Outcome above. Commit with `docs(CICD-02): record CI/CD pipeline verification evidence`. Then `/gsd-transition` to mark the milestone complete.
