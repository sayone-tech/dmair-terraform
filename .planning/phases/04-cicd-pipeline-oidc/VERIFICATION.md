# Phase 4: CI/CD Pipeline + OIDC — Verification Evidence

**Status:** TEMPLATE — pending DevOps execution.

**Date:** _(YYYY-MM-DD)_
**Verifier:** _(DevOps name)_
**Outcome:** _PASS / FAIL_

---

## Pre-verification — Create the OIDC IDP + 4 IAM roles

Follow [`docs/iam-oidc/README.md`](../../../docs/iam-oidc/README.md) end-to-end. After Step 2 of that doc, you should be able to:

```sh
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')]"

for role in dmair-terraform-plan-readonly \
            dmair-terraform-staging-apply \
            dmair-terraform-prod-apply \
            dmair-backend-staging-deploy; do
  aws iam get-role --role-name "$role" --query 'Role.{Name:RoleName,Arn:Arn,Trust:AssumeRolePolicyDocument.Statement[0].Condition}' --output table
done
```

```text
TODO_DEVOPS: paste the OIDC IDP ARN + the 4 role ARNs.
```

---

## Pre-verification — Configure GitHub Environments + Secrets

Settings → Environments → `prod`:
- Required reviewers: _(at least one)_
- Deployment branches: `main` only

Settings → Secrets and variables → Actions → Repository secrets:

| Secret | Set |
|---|---|
| `AWS_PLAN_ROLE_ARN` | _( yes / no )_ |
| `AWS_STAGING_APPLY_ROLE_ARN` | _( yes / no )_ |
| `AWS_PROD_APPLY_ROLE_ARN` | _( yes / no )_ |
| `STAGING_BACKEND_DB_PASSWORD` | _( yes / no )_ |
| `STAGING_BACKEND_JWT_SECRET` | _( yes / no )_ |
| `STAGING_BACKEND_MAIL_PASSWORD` | _( yes / no )_ |
| `STAGING_BACKEND_ADMIN_PASSWORD` | _( yes / no )_ |

```text
TODO_DEVOPS: confirm all seven Secrets are set and the `prod` Environment exists with reviewers.
```

---

## CICD-01 #1 — PR triggers `plan` + comment + merge gate

1. Open a no-op PR touching one stack.
2. The `detect-changes` + `plan` jobs run; the two `apply-*` jobs are skipped (because `github.event_name == 'pull_request'`).
3. The `plan` job posts a comment on the PR.
4. The PR's "merge" button is disabled because `terraform / plan` is a required status check.

```text
TODO_DEVOPS: paste link to the PR (or screenshot the workflow + PR comment). Confirm:
  - plan job ran for the touched stack only
  - apply jobs did NOT run
  - PR comment posted with `terraform plan` output
  - merge button blocked
```

---

## CICD-01 #2 + CICD-02 #1 — Manual dispatch → staging applies + prod gated

Merge a staging-only change (e.g., touch `live/dmair/frontend/staging/main.tf` or `live/dmair/backend/staging/cloudwatch.tf`). Confirm:

- Post-merge `plan` job runs and uploads the plan artifact.
- **Apply does NOT auto-run.**
- Actions → `terraform` workflow → **Run workflow** → pick the staging stack → Run.
- `apply-staging` runs end-to-end without any reviewer interaction.

```text
TODO_DEVOPS: paste two workflow run links — the post-merge plan run + the manually-dispatched apply run.
```

Now merge a prod-affecting change (e.g., touch `bootstrap/main.tf` or `live/dmair/frontend/prod/main.tf`). Confirm:

- Post-merge `plan` job runs.
- Apply does NOT auto-run.
- Manually dispatch the apply for the prod stack.
- `apply-prod` pauses on the `prod` Environment gate. The Actions run shows a "Review pending deployment" prompt.
- An approved reviewer clicks "Approve and deploy". The job resumes.
- `apply-prod` succeeds with the prod-apply role assumed.

```text
TODO_DEVOPS: paste workflow run link showing the reviewer-gate prompt + post-approval apply success.
```

---

## CICD-02 #3 — No-escalation invariant

Attempt to add an IAM role that escapes the scoped name prefixes — e.g., a role named `not-in-scope-attacker-role` in `live/dmair/strapi/prod/main.tf`. Push to a branch, open PR:

- `plan` job should succeed (plan is permissive — it can plan a role create).
- Merge to main → manually dispatch `apply-prod` against `live/dmair/strapi/prod`. Reviewer approves. The apply should then FAIL with an `AccessDenied` on `iam:CreateRole` because the role name doesn't match the prefix list in `dmair-terraform-prod-apply`'s policy.

Revert the test change after the failure.

```text
TODO_DEVOPS: paste the AccessDenied error from the failing apply. This is the no-escalation evidence.
```

---

## CICD-02 #4 — `docs/iam-oidc/README.md` complete

Spot-check that [`docs/iam-oidc/README.md`](../../../docs/iam-oidc/README.md) contains:

- [ ] OIDC trust provider setup command (URL, audience, thumbprint)
- [ ] All four roles enumerated (plan-readonly, staging-apply, prod-apply, dmair-backend-staging-deploy) with file references
- [ ] Setup procedure: render templates locally, create roles + inline policies, never commit rendered files
- [ ] GitHub Secrets table
- [ ] `prod` Environment configuration guide
- [ ] Branch protection guide
- [ ] Rotation + rollback procedures
- [ ] Design notes (why per-role trust, why inline policies, why manual)

```text
TODO_DEVOPS: tick each box or note specific gaps.
```

---

## Phase Exit

- [ ] **CICD-01** — PR triggers plan + PR comment + merge-gate; staging applies on manual dispatch; prod gated by `prod` Environment with reviewers
- [ ] **CICD-02** — All four OIDC roles enumerated in `docs/iam-oidc/`; no-escalation invariant enforced (apply fails for IAM names outside the role's prefix list)

Set Outcome above. Commit with `docs(CICD-02): record CI/CD pipeline verification evidence`. Then `/gsd-transition` to mark the milestone complete.
