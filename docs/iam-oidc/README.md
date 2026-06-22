# IAM Roles for GitHub Actions OIDC

These JSON files are templates for the ops team to create IAM roles that GitHub Actions workflows assume via OIDC federation. They are **NOT managed by Terraform** — ops creates them out-of-band.

> **Important:** All JSON files contain placeholders (`ACCOUNT_ID`, `ORG/REPO`, `BACKEND_ORG/BACKEND_REPO`, `STAGING_EC2_INSTANCE_ID`). They are safe to commit as-is. **Never put real account IDs or ARNs into these files.** Ops fills in the real values locally when creating the roles — the actual role ARNs go into GitHub Secrets, not into any file in this repo.

---

## Before you start

**Pre-requisite:** An OIDC identity provider must exist in the AWS account:

```
Provider URL : https://token.actions.githubusercontent.com
Audience     : sts.amazonaws.com
Thumbprint   : 6938fd4d98bab03faadb97b34396831e3780aea1
```

Create it once via the CLI (or AWS console → IAM → Identity providers → Add provider):

```sh
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Idempotency: this fails with `EntityAlreadyExists` if the IDP already exists — which is the desired no-op behaviour for re-runs.

---

## Files

| File | Purpose |
|---|---|
| `dmair-terraform-plan-readonly-trust.json` | Trust policy for the plan-readonly role — `ACCOUNT_ID` + `ORG/REPO` placeholders. Subject allows PR + push-to-main. |
| `dmair-terraform-plan-readonly-permissions.json` | Refresh-only `Describe*`/`Get*`/`List*` perms + state-bucket read + `.tflock` RW. Includes `budgets:ListTagsForResource` (budget refresh) and a single `secretsmanager:GetSecretValue` scoped to `dmair/staging/app-*` only (needed to refresh the managed `aws_secretsmanager_secret_version`; no broad secret read). |
| `dmair-terraform-staging-apply-trust.json` | Trust policy for staging-apply — `ACCOUNT_ID` + `ORG/REPO` placeholders. Subject restricted to `ref:refs/heads/main`. |
| `dmair-terraform-staging-apply-permissions.json` | plan-readonly perms + scoped staging writes — `ACCOUNT_ID` placeholder. (Single file; size fits inline policy limit.) |
| `dmair-terraform-prod-apply-trust.json` | Trust policy for prod-apply — `ACCOUNT_ID` + `ORG/REPO` placeholders. Subject restricted to `environment:prod` (GitHub Environment with required reviewers is the load-bearing gate). |
| `dmair-terraform-prod-apply-permissions.json` | plan-readonly perms + broader prod-prefix writes — `ACCOUNT_ID` placeholder. |
| `dmair-backend-staging-deploy-trust.json` | **Cross-repo** trust policy for the dmair-backend deploy role — `ACCOUNT_ID` + `BACKEND_ORG/BACKEND_REPO` placeholders. Trusted by the dmair-backend repo, not this one. |
| `dmair-backend-staging-deploy-permissions.json` | ECR push/pull on `dmair-backend` repo + Secrets read on `dmair/staging/app` + SSM SendCommand/StartSession on the staging EC2 instance only. `ACCOUNT_ID` + `STAGING_EC2_INSTANCE_ID` placeholders. |

---

## Setup instructions

Run these steps locally (do **NOT** commit the filled-in files back to the repo).

### 1. Prepare the policy files locally

```sh
cd docs/iam-oidc

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TF_ORG_REPO="sayone-tech/dmair-terraform"        # this repo
BACKEND_ORG_REPO="DM-Air/dmair-backend"          # cross-repo contract — DIFFERENT org from this repo. The OIDC token sub is repo:DM-Air/dmair-backend:ref:refs/heads/staging, so this MUST be DM-Air or the deploy role's trust never matches (configure-aws-credentials fails at deploy step 1). Do not "align" it to the terraform repo's org.
STAGING_EC2_INSTANCE_ID="i-PLACEHOLDER"          # fill in AFTER applying live/dmair/backend/staging (Phase 3)

mkdir -p /tmp/iam-oidc
for f in dmair-terraform-plan-readonly-trust.json \
         dmair-terraform-plan-readonly-permissions.json \
         dmair-terraform-staging-apply-trust.json \
         dmair-terraform-staging-apply-permissions.json \
         dmair-terraform-prod-apply-trust.json \
         dmair-terraform-prod-apply-permissions.json \
         dmair-backend-staging-deploy-trust.json \
         dmair-backend-staging-deploy-permissions.json; do
  sed -e "s/ACCOUNT_ID/${ACCOUNT_ID}/g" \
      -e "s|BACKEND_ORG/BACKEND_REPO|${BACKEND_ORG_REPO}|g" \
      -e "s|ORG/REPO|${TF_ORG_REPO}|g" \
      -e "s/STAGING_EC2_INSTANCE_ID/${STAGING_EC2_INSTANCE_ID}/g" \
      "$f" > "/tmp/iam-oidc/$f"
done
```

> The `sed` order matters: `BACKEND_ORG/BACKEND_REPO` is substituted **before** `ORG/REPO` because the latter is a substring of the former.

### 2. Create the roles

```sh
cd /tmp/iam-oidc

# --- dmair-terraform-plan-readonly (inline policy — fits 10K limit) ---
aws iam create-role \
  --role-name dmair-terraform-plan-readonly \
  --description "GitHub Actions assumes this on PRs + push-to-main to terraform plan against every stack (read-only)." \
  --assume-role-policy-document file://dmair-terraform-plan-readonly-trust.json \
  --max-session-duration 3600

aws iam put-role-policy \
  --role-name dmair-terraform-plan-readonly \
  --policy-name terraform-plan-readonly \
  --policy-document file://dmair-terraform-plan-readonly-permissions.json

# --- dmair-terraform-staging-apply (inline policy) ---
aws iam create-role \
  --role-name dmair-terraform-staging-apply \
  --description "GitHub Actions assumes this on workflow_dispatch (push-to-main) to apply live/dmair/<component>/staging stacks." \
  --assume-role-policy-document file://dmair-terraform-staging-apply-trust.json \
  --max-session-duration 3600

aws iam put-role-policy \
  --role-name dmair-terraform-staging-apply \
  --policy-name terraform-staging-apply \
  --policy-document file://dmair-terraform-staging-apply-permissions.json

# --- dmair-terraform-prod-apply (inline policy) ---
aws iam create-role \
  --role-name dmair-terraform-prod-apply \
  --description "GitHub Actions assumes this only with environment:prod (required-reviewer gate) to apply bootstrap + live/dmair/<component>/prod." \
  --assume-role-policy-document file://dmair-terraform-prod-apply-trust.json \
  --max-session-duration 3600

aws iam put-role-policy \
  --role-name dmair-terraform-prod-apply \
  --policy-name terraform-prod-apply \
  --policy-document file://dmair-terraform-prod-apply-permissions.json

# --- dmair-backend-staging-deploy (cross-repo; inline policy) ---
# Create only AFTER live/dmair/backend/staging has been applied — you need
# the staging EC2 instance ID to fill in the trust + permissions templates.
aws iam create-role \
  --role-name dmair-backend-staging-deploy \
  --description "Cross-repo OIDC role. Assumed by the dmair-backend repo's CI on the staging branch to push ECR images, read secrets, and SSM-deploy to the staging EC2." \
  --assume-role-policy-document file://dmair-backend-staging-deploy-trust.json \
  --max-session-duration 3600

aws iam put-role-policy \
  --role-name dmair-backend-staging-deploy \
  --policy-name dmair-backend-staging-deploy \
  --policy-document file://dmair-backend-staging-deploy-permissions.json

# Clean up local copies — these contain real ACCOUNT_ID / instance IDs.
rm -rf /tmp/iam-oidc
```

### 3. Add GitHub repository secrets

In the dmair-terraform repo: **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `AWS_PLAN_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-plan-readonly` |
| `AWS_STAGING_APPLY_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-staging-apply` |
| `AWS_PROD_APPLY_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/dmair-terraform-prod-apply` |
| `STAGING_BACKEND_DB_PASSWORD` | strong generated password (RDS master) |
| `STAGING_BACKEND_JWT_SECRET` | HS512 signing key, ≥64 chars (`openssl rand -hex 64`) |
| `STAGING_BACKEND_MAIL_PASSWORD` | SendGrid API key |
| `STAGING_BACKEND_ADMIN_PASSWORD` | initial admin password, 12-128 chars |

In the **dmair-backend** repo (cross-repo contract): add **one** secret pointing at the dmair-backend-staging-deploy role:

| Secret | Value |
|---|---|
| `AWS_STAGING_DEPLOY_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/dmair-backend-staging-deploy` |

### 4. Configure the `prod` GitHub Environment

In the dmair-terraform repo: **Settings → Environments → New environment → `prod`**:

- **Required reviewers:** at least 1 (recommended: 2).
- **Deployment branches:** restrict to `main` only.

Without this Environment, the workflow's `apply-prod` job has nothing to pause on — apply would run without review.

### 5. Enable branch protection on `main`

**Settings → Branches → Branch protection rules → `main`**:

- Tick **Require status checks to pass before merging**.
- Add the matrix variants of `terraform / plan (...)` as required checks.

---

## Verification

Smoke-test each role's trust + permissions independently:

```sh
# Trust check — simulate the AssumeRole call (requires a real GitHub OIDC token,
# easier to test by triggering the workflow). For a quick offline check:
aws iam get-role --role-name dmair-terraform-plan-readonly \
  --query 'Role.AssumeRolePolicyDocument.Statement[0].Condition'
# Should show the StringEquals + StringLike conditions you applied.

# Permission check — verify the scope is what you expect:
aws iam get-role-policy \
  --role-name dmair-terraform-prod-apply \
  --policy-name terraform-prod-apply \
  --query 'PolicyDocument.Statement[].Sid'
# Should list StateBucketRead, DescribeAllForRefresh, StateBucketWriteAll, ...
```

End-to-end smoke test:

1. Open a no-op PR. The `plan` job should run and post a comment. Check workflow logs for `Authenticated as arnId AROA…:GitHubActions` — that confirms OIDC works.
2. Merge a staging-only PR; manually dispatch `apply-staging`. Confirms `dmair-terraform-staging-apply` works.
3. Merge a prod-affecting PR; manually dispatch `apply-prod`. The job pauses on the `prod` Environment gate. Approve. Confirms `dmair-terraform-prod-apply` + the required-reviewer gate.

If any step fails with `AccessDenied: Not authorized to perform: sts:AssumeRoleWithWebIdentity`, the most common cause is a mismatch between the OIDC token's `sub` claim and the role's trust-policy `StringLike` patterns. Inspect the token with [`debug-print-jwt`](https://github.com/aws-actions/configure-aws-credentials#debug-print-jwt) or by adding `core.info(JSON.stringify(...))` to a `github-script` step.

---

## Rotation & rollback

**To rotate a role's permissions:**

```sh
# Edit the JSON template locally, re-run the sed in Step 1, then:
aws iam put-role-policy \
  --role-name <role-name> \
  --policy-name <policy-name> \
  --policy-document file:///tmp/iam-oidc/<role>-permissions.json
```

`put-role-policy` is idempotent — it overwrites the inline policy in place.

**To rotate the trust policy:**

```sh
aws iam update-assume-role-policy \
  --role-name <role-name> \
  --policy-document file:///tmp/iam-oidc/<role>-trust.json
```

**To revoke a role entirely:**

```sh
aws iam delete-role-policy --role-name <role-name> --policy-name <policy-name>
aws iam delete-role --role-name <role-name>
```

Once deleted, the corresponding GitHub Secret (`AWS_*_ROLE_ARN`) becomes inert — workflows referencing it will fail at the `configure-aws-credentials` step with `AccessDenied`, which is the desired behaviour.

---

## Design notes

**Why per-role trust (not one shared trust file).** Some convention guides use one `trust-policy.json` shared across every role. Tighter security demands per-role trust:

- `dmair-terraform-plan-readonly` trusts PR runs + push-to-main → safe to be permissive.
- `dmair-terraform-staging-apply` trusts only `ref:refs/heads/main` → can't be assumed from a PR.
- `dmair-terraform-prod-apply` trusts only `environment:prod` → can't be assumed without the GitHub Environment gate firing (which requires reviewer approval).

If all three shared the same broad trust, the prod-apply role could be assumed from a PR. The IAM permission scope would still constrain blast radius, but the defense-in-depth from trust scoping is gone.

**Why inline policies (not managed).** Each role has exactly one policy attached; nothing else attaches to the same policy. Inline is simpler to audit (`aws iam get-role-policy` returns the actual JSON, no second resource to look up) and tracks the role's lifecycle (delete the role → policy gone). If a future role needs to attach to multiple roles, convert to a managed policy via `aws iam create-policy` + `aws iam attach-role-policy`.

**Why not Terraform-managed.** Originally these roles were created by a `platform/oidc/` Terraform stack. Three reasons we moved to manual ops management:

1. **Chicken-and-egg.** The terraform CI roles are the ones that run `terraform apply` from CI. If they're managed by Terraform, the very first apply has to come from somewhere — either an operator running it manually (in which case the Terraform stack is doing nothing the operator couldn't do directly), or a bootstrap-yourself loop that's brittle.
2. **Separation of concerns.** IAM trust is a security boundary; developers iterating on app code shouldn't accidentally widen it via a Terraform merge.
3. **Easier rotation.** `aws iam update-assume-role-policy` is a single API call. The Terraform path requires plan → review → apply → CI re-trigger, slower and more error-prone for a security-sensitive change.

The trade-off: drift between the JSON in this directory and what's deployed is possible. Mitigate by reviewing any change to the JSON files via PR and re-running Step 2's `put-role-policy` / `update-assume-role-policy` immediately on merge.
