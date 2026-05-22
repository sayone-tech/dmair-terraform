# Terraform + GitHub Actions OIDC — Reference Setup Guide

A reference guide for setting up a Terraform monorepo with GitHub Actions OIDC federation to AWS. Generalized from the dmair-terraform milestone; intended to be reused for new projects.

What this gets you:
- Terraform state in a single S3 bucket per AWS account, with S3-native locking (no DynamoDB lock table needed).
- GitHub Actions assumes AWS IAM roles via OIDC — **no long-lived AWS access keys in repo secrets**.
- PR-gated `terraform plan` with plan output posted as a PR comment + required status check.
- Manual `workflow_dispatch` apply per stack (no auto-apply on push).
- A `prod` GitHub Environment with required reviewers gating prod-stack applies.
- IAM scoping per role: plan-readonly, staging-apply (scoped writes), prod-apply (scoped writes with GitHub-Environment gate).

---

## 1. Architecture

```
                       GitHub Actions workflow
                                │
              "id-token: write" job permission
                                ▼
                  ┌──── GitHub OIDC issuer
                  │     token.actions.githubusercontent.com
                  │     mints JWT with claims:
                  │       iss, aud=sts.amazonaws.com,
                  │       sub=repo:<org>/<repo>:<context>
                  ▼
        aws-actions/configure-aws-credentials@v4
                                │
                                ▼
            AWS STS:AssumeRoleWithWebIdentity
                                │
       AWS validates against IAM Identity Provider
       (registered to trust the GitHub OIDC issuer)
                                │
       AWS evaluates the target role's trust policy:
         - principal Federated == github oidc provider ARN
         - StringEquals  :aud == sts.amazonaws.com
         - StringLike    :sub matches our pattern
                                │
                                ▼
           Returns short-lived credentials (1 hour)
           with the role's inline permission policy
                                │
                                ▼
              Terraform's AWS provider uses them
              via the standard SDK credential chain
              (env vars first → no profile lookup)
```

Four pieces have to align for this to work:

1. **`id-token: write`** job-level permission in the workflow.
2. **`aws_iam_openid_connect_provider`** registered in the AWS account.
3. **Trust policy** on each role that StringLike-matches the OIDC `sub` claim format GitHub emits.
4. **Inline permission policy** on each role granting only what that role needs.

Miss any one and you get `Not authorized to perform: sts:AssumeRoleWithWebIdentity` (almost always traceable to the `sub` claim or the IDP not existing).

---

## 2. Roles design (per AWS account)

A new project typically wants four roles, one per concern:

| Role | Assumed by | Scope |
|---|---|---|
| `<project>-tf-plan-readonly` | Every PR + push-to-main | Read-only across the account. Refreshes state. `terraform plan` only. NEVER `secretsmanager:GetSecretValue`. |
| `<project>-tf-staging-apply` | `workflow_dispatch` from `main` | Writes scoped to staging tag (`aws:RequestTag/Environment=staging`) and name prefixes (`<project>-staging-*`). Inherits all plan-readonly statements. |
| `<project>-tf-prod-apply` | `workflow_dispatch` with `environment: prod` | Writes scoped to prod name prefixes. Primary safety control is the GitHub Environment with required reviewers — the OIDC `sub` claim is `repo:.../environment:prod` only when the Environment fires (i.e., after reviewer approval). |
| `<project>-app-deploy` | Cross-repo (the app code's CI) | Pushes container images to ECR, reads secrets, SSM-deploys to instances. NO terraform privileges. Per-ARN scoped (no wildcards). |

**Why per-role trust, not one shared `trust-policy.json`:** so the prod-apply role literally cannot be assumed without the GitHub Environment gate firing — defense in depth on top of IAM permission scoping.

**Why inline policies, not managed:** each role has exactly one policy. Inline tracks the role's lifecycle (delete role → policy gone). Convert to managed only when you need to attach the same policy to multiple roles.

---

## 3. Pre-flight (one-time, per AWS account)

### Register the GitHub OIDC identity provider

```sh
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Idempotent: subsequent runs fail with `EntityAlreadyExists`, which is fine.

The thumbprint changes when GitHub rotates its TLS cert (rare). If GitHub Actions starts failing with `OidcUnknownThumbprint`, update via `aws iam update-open-id-connect-provider-thumbprint`.

### Create the Terraform state bucket

```sh
PROJECT=<your-project>
REGION=us-west-2
BUCKET=${PROJECT}-terraform-prod   # convention

aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}, "BucketKeyEnabled": true}]
  }'
```

Versioning is optional — best practice is on (`aws s3api put-bucket-versioning --versioning-configuration Status=Enabled`), but our reference repo intentionally left it off to keep import overhead low. If you turn it on, the `bootstrap` stack's `aws_s3_bucket_versioning.this.versioning_configuration.status` should be `"Enabled"` to match.

State locking uses Terraform 1.10+'s S3-native `use_lockfile = true` — a `.tflock` sentinel object next to each `terraform.tfstate`. No DynamoDB table is needed. Old guides that say "create a `<project>-terraform-locks` DynamoDB table" are obsolete with Terraform ≥ 1.10.

---

## 4. Repo layout

A layout that scales as the project grows past one component/environment:

```
<repo-root>/
├── bootstrap/                          State backend stack (adopts the
│                                       pre-existing dmair-terraform-prod
│                                       bucket into IaC via terraform
│                                       import).
│
├── live/<project>/                     Live workloads, organized
│   │                                   component-first then environment:
│   ├── <component-A>/
│   │   ├── prod/
│   │   └── staging/
│   ├── <component-B>/
│   │   └── prod/
│   └── ...
│
├── modules/                            Reusable local Terraform modules.
│   ├── vpc/  ec2/  rds/  s3/  iam-policy/  iam-role/  iam-user/
│   ├── cloudfront/  cloudfront-function/
│   ├── ecr/  eip/  sg/  secrets_manager/
│   └── ...
│
├── policies/                           IAM policy JSON templates rendered
│   │                                   via templatefile() by
│   │                                   modules/iam-policy.
│   ├── s3_rw.tpl       ecr_pull.tpl
│   ├── ecr_push.tpl    secrets_manager_read.tpl
│   ├── ec2_app_runtime.tpl    (per-app runtime role)
│   └── ...
│
├── docs/
│   ├── iam-oidc/                       JSON templates for the OIDC-trusted
│   │                                   IAM roles. NOT managed by Terraform
│   │                                   — created out-of-band by ops.
│   │   ├── README.md                   Setup walkthrough.
│   │   ├── <project>-tf-plan-readonly-trust.json
│   │   ├── <project>-tf-plan-readonly-permissions.json
│   │   ├── <project>-tf-staging-apply-{trust,permissions}.json
│   │   ├── <project>-tf-prod-apply-{trust,permissions}.json
│   │   └── <project>-app-deploy-{trust,permissions}.json
│   └── TERRAFORM-OIDC-SETUP.md         This document.
│
└── .github/workflows/terraform.yml     PR plan + workflow_dispatch apply.
```

**Why component-first under `live/`:** the alternative (env-first: `live/<project>/prod/<component>/`) groups everything in one environment together but spreads a component across two trees. Component-first lets you see all environments of a component side-by-side (`live/<project>/frontend/{prod,staging}/`), which matches how teams reason about ownership.

**Why `bootstrap/` is special:** the bucket it manages is also where its own state lives. The first apply uses `terraform import` blocks to adopt the pre-existing bucket. After the first applied plan reports `No changes`, a follow-up commit removes the `import {}` blocks (HashiCorp best practice).

**Why `docs/iam-oidc/` is NOT Terraform-managed:** the IAM roles are what Terraform CI assumes to run. Managing the roles with Terraform creates a chicken-and-egg loop — the first apply has to come from an operator with elevated perms, which means the Terraform stack is doing nothing the operator couldn't do directly. Plus, IAM trust is a security boundary; app developers iterating on workload code shouldn't accidentally widen it via a `feature/*` merge. Manual creation with JSON templates committed (placeholders only, real ARNs go to GitHub Secrets) gives faster rotation (`update-assume-role-policy` is one API call) and clean separation.

---

## 5. The non-obvious gotchas — and their fixes

These are the failures the dmair-terraform setup hit during the smoke test. Each one wasted ~15-60 min of debugging the first time. Capture them here so the next setup doesn't.

### 5.1 Hardcoded `profile` + `shared_credentials_files` in backend.tf breaks OIDC

**Symptom:** workflow's `configure-aws-credentials` step succeeds (you see `Authenticated as arnId AROA…:GitHubActions`), but the next step (`terraform init` or `terraform plan`) fails with `NoCredentialProviders` or `failed to find shared credentials file`.

**Cause:** if `backend.tf` or `provider "aws" {}` has `profile = "..."`, the AWS provider's credential chain uses the named profile lookup instead of the env vars that `configure-aws-credentials` exported. In CI there's no `~/.aws/credentials` file, so the lookup fails.

**Fix:** **never** hardcode `profile` or `shared_credentials_files` in backend.tf / providers.tf. Both should look like:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket       = "<project>-terraform-prod"
    key          = "<component>/<env>/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}

# providers.tf
provider "aws" {
  region = var.aws_region
}
```

Local operators set `export AWS_PROFILE=<profile-name>` before running terraform. CI sets `AWS_*` env vars via OIDC. Both work because the AWS SDK credential chain checks env vars first, then shared credentials file, then IMDS.

### 5.2 `terraform plan -detailed-exitcode` exit code 2 aborts the workflow step

**Symptom:** CI shows `Error: Process completed with exit code 2.` on a perfectly valid `terraform plan` that has drift. Plan comment is never posted; merge is blocked.

**Cause:** GitHub Actions runs every `run:` block with `bash -eo pipefail`. `terraform plan -detailed-exitcode` returns:
- `0` = no changes
- `1` = error  
- `2` = changes detected — **success**, but a non-zero exit

With `-e` (errexit) on, exit 2 immediately aborts the script. The "interpret the exit code" logic in your workflow never runs.

**Fix:** wrap the plan call in `set +e` / `set -e`:

```yaml
- name: terraform plan
  run: |
    set +e
    set -o pipefail
    terraform plan -no-color -input=false -detailed-exitcode -out=tfplan 2>&1 | tee plan.txt
    ec=${PIPESTATUS[0]}
    set -e
    if [ "$ec" -eq 1 ]; then exit 1; fi
    # 0 and 2 are both success
```

### 5.3 `terraform plan` reports "bucket has been deleted" / phantom drift

**Symptom:** From CI (OIDC role), `terraform plan` reports a long list of S3 bucket sub-resources as `must be replaced` / `forces replacement` and adds the bucket itself. From an admin profile locally, the same plan reports `No changes`. Plan output includes:

```
Note: Objects have changed outside of Terraform
  # module.<x>.aws_s3_bucket.<y> has been deleted
```

…even though the bucket clearly exists.

**Cause:** the AWS provider calls `HeadBucket` during refresh, which requires the **`s3:ListBucket`** IAM action (despite the API method being named `HeadBucket`). If the role lacks `s3:ListBucket` on the workload bucket, the provider silently treats the 403 as "bucket doesn't exist" → plans to recreate.

**Fix:** add `s3:ListBucket` to the role's refresh statement on `Resource: "*"` (or scoped to a bucket name pattern if you can enumerate them). Example IAM policy fragment:

```json
{
  "Sid": "DescribeAllForRefresh",
  "Effect": "Allow",
  "Action": [
    "s3:GetBucket*",
    "s3:Get*Configuration",
    "s3:ListBucket",
    "s3:ListAllMyBuckets",
    ...
  ],
  "Resource": "*"
}
```

`s3:ListBucket` on `*` allows listing object keys in any bucket but does NOT allow reading object contents. For a plan-readonly role this is acceptable.

### 5.4 `cloudfront:Describe*` not covered by `cloudfront:Get*` wildcard

**Symptom:** `terraform plan` against a stack with a `aws_cloudfront_function` resource fails with:

```
AccessDenied: User: arn:aws:sts::...:assumed-role/<plan-role>/GitHubActions
  is not authorized to perform: cloudfront:DescribeFunction
```

**Cause:** AWS's IAM action prefixes don't form a clean hierarchy. `cloudfront:Get*` matches most CloudFront read actions, but **not** `cloudfront:DescribeFunction` (and `cloudfront:DescribeKeyValueStore`). These need `cloudfront:Describe*` explicitly.

**Fix:** include `cloudfront:Describe*` alongside `cloudfront:Get*` and `cloudfront:List*` in any role that refreshes a CloudFront function.

### 5.5 S3 bucket-config Get actions don't all start with `GetBucket*`

**Symptom:** After fixing 5.3, plan still fails with `AccessDenied` on `s3:GetAccelerateConfiguration` or similar.

**Cause:** AWS S3 has two naming conventions for bucket-config get actions:
- `s3:GetBucketCors`, `s3:GetBucketVersioning`, etc. — covered by `s3:GetBucket*`
- `s3:GetAccelerateConfiguration`, `s3:GetAnalyticsConfiguration`, `s3:GetEncryptionConfiguration`, `s3:GetIntelligentTieringConfiguration`, `s3:GetInventoryConfiguration`, `s3:GetLifecycleConfiguration`, `s3:GetMetricsConfiguration`, `s3:GetReplicationConfiguration` — **not** covered by `s3:GetBucket*` even though the underlying API methods are named `GetBucket...Configuration`.

**Fix:** add the `s3:Get*Configuration` wildcard. It matches all the non-`GetBucket*`-prefixed bucket-config get actions but does NOT match `s3:GetObject` (the object content read), so secrets-in-objects stay protected.

### 5.6 The bucket's name in HCL must EXACTLY match the live bucket

**Symptom:** `terraform plan` shows `Plan: X to add, 0 to change, X to destroy` where the destroy-then-recreate diff is on resources whose only "change" is a `(known after apply)` value.

**Cause:** the bucket's `bucket = lower("${var.APP_NAME}-${var.ENV}")` template doesn't match the live bucket name. Causes:
- `APP_NAME` or `ENV` value differs between branch's `terraform.tfvars` and what was originally applied.
- Whitespace, casing, or template-expression differences.

**Fix:** verify `aws s3 ls` against the live bucket; ensure the computed name matches exactly. Note: a permission-related "phantom deletion" (5.3) looks identical to this bug from the plan output. Always rule out 5.3 first by checking from an admin profile.

### 5.7 IAM action wildcards in inline policy can hit the 10 KB limit

**Symptom:** `aws iam put-role-policy` fails with `LimitExceeded: Cannot exceed quota for InlinePolicyMaximumSize: 10240`.

**Cause:** scoped per-resource policies expand fast — every prefix-scoped IAM action across every relevant resource type adds 100+ chars.

**Fix:**
1. Replace explicit lists with wildcards where safe: `s3:GetBucket*` instead of 15 named actions.
2. Split into multiple statements with shared `Resource` blocks.
3. Convert from inline (10 KB cap) to managed policy (6 KB per managed policy, but you can attach multiple).

If you're approaching the limit, you have too many statements — that's usually a signal to split the role.

### 5.8 GitHub Actions `${{ secrets.MISSING_NAME }}` resolves to empty string

**Symptom:** `terraform plan` runs successfully in CI even though a required `TF_VAR_*` env var should have caused a "No value for required variable" error.

**Cause:** if a repo secret with that name doesn't exist, GitHub Actions silently resolves `${{ secrets.* }}` to an empty string instead of erroring. Terraform happily accepts `""` as a valid value for any string variable, including sensitive ones.

**Implication:** `terraform plan` works fine with empty-string secrets. `terraform apply` would write **literally empty passwords** into Secrets Manager. Footgun.

**Fix:** add a workflow guard that fails fast if any required sensitive var is empty:

```yaml
- name: Validate sensitive vars are populated
  if: contains(matrix.stack, 'backend')   # only for stacks that need secrets
  env:
    DB:    ${{ secrets.STAGING_BACKEND_DB_PASSWORD }}
    JWT:   ${{ secrets.STAGING_BACKEND_JWT_SECRET }}
    MAIL:  ${{ secrets.STAGING_BACKEND_MAIL_PASSWORD }}
    ADMIN: ${{ secrets.STAGING_BACKEND_ADMIN_PASSWORD }}
  run: |
    for name in DB JWT MAIL ADMIN; do
      val="${!name}"
      if [ -z "$val" ]; then
        echo "::error::Required secret STAGING_BACKEND_${name} is empty"
        exit 1
      fi
    done
```

### 5.9 `templatefile()` and literal `${...}` in your template

**Symptom:** `terraform validate` fails with `Invalid expression; Expected the start of an expression, but found an invalid expression token` on a comment line containing `${}`.

**Cause:** `templatefile()` evaluates EVERY `${...}` in the file as a Terraform expression, including ones in shell comments. A literal `${}` (empty braces) is invalid.

**Fix:** 
- Escape `${...}` in source as `$${...}` to produce literal `${...}` in output.
- Or reword comments to avoid the `${}` character sequence entirely.

This bites particularly hard when the template is a shell script with `${VAR}` references AND a docker-compose YAML with `$${VAR}` escape sequences (both interpreted by docker compose). Using a `<<'COMPOSE'` heredoc to keep the YAML literal-safe + a separate sed pass for the Terraform variables avoids the collision.

### 5.10 SG `description` can't contain apostrophes

**Symptom:** `terraform validate` fails with:

```
Error: "egress.0.description" doesn't comply with restrictions
  ("^[0-9A-Za-z_ .:/()#,@\\[\\]]+=&;{}!$*-]*$"): "All egress (... Let's Encrypt ...)"
```

**Cause:** AWS Security Group descriptions have a strict regex allowlist. No apostrophes, no smart quotes, no backslash.

**Fix:** reword. `Let's` → `Lets`, or drop the possessive entirely.

---

## 6. Setup checklist for a new project

Step-by-step, from blank repo to a green smoke-test PR. Estimated wall time: ~90 minutes for someone who's done it before, ~4 hours first time.

### One-time per AWS account

- [ ] Register the GitHub OIDC identity provider (§3).
- [ ] Create the Terraform state bucket with encryption + public-access-block (§3).

### One-time per project

- [ ] Create the repo on GitHub.
- [ ] Set up the layout (§4) — `bootstrap/`, `live/<project>/`, `modules/`, `policies/`, `docs/iam-oidc/`, `.github/workflows/`.
- [ ] Write `bootstrap/main.tf` with `import {}` blocks for the state bucket sub-resources (versioning, encryption, PAB, optional tags). Mirror the live state via `aws s3api get-bucket-*` snapshot before writing the HCL.
- [ ] Create the 4 OIDC JSON templates under `docs/iam-oidc/` with placeholders only.
- [ ] Write `docs/iam-oidc/README.md` walkthrough.
- [ ] Write `.github/workflows/terraform.yml` with detect-changes + plan matrix + workflow_dispatch apply jobs.
- [ ] Commit, push, open PR for review.

### Operator setup (manual, follows `docs/iam-oidc/README.md`)

- [ ] `aws sts get-caller-identity` — confirm you have IAM write perms.
- [ ] Render the 4 OIDC JSON templates with `ACCOUNT_ID` + `ORG/REPO` substituted (sed recipe in §3 of the iam-oidc README).
- [ ] `aws iam create-role` + `put-role-policy` for the 4 roles.
- [ ] Capture the 4 role ARNs from `terraform output` or `aws iam get-role`.
- [ ] Add the 3 terraform-CI role ARNs to repo Secrets as `AWS_PLAN_ROLE_ARN`, `AWS_STAGING_APPLY_ROLE_ARN`, `AWS_PROD_APPLY_ROLE_ARN`.
- [ ] Add the 4th role ARN to the app-code repo's Secrets (cross-repo contract).
- [ ] Configure the `prod` GitHub Environment with required reviewers, branches=main only.
- [ ] Enable branch protection on `main` with `terraform / Detect changed stacks` as a required status check.

### Smoke test (load-bearing — this is what proves OIDC works)

- [ ] Open a no-op PR touching one stack file (`echo "" >> live/<project>/<component>/<env>/main.tf`).
- [ ] Watch the workflow run. All `terraform plan — *` jobs should be green.
- [ ] Verify the PR has a plan-output comment for each touched stack.
- [ ] Look in the `Configure AWS credentials (plan role)` step's log for `Authenticated as arnId AROA…:GitHubActions` — that's the conclusive OIDC-works proof.
- [ ] Close the PR without merging.

### Phase 1 — first apply (DevOps owns)

- [ ] Bootstrap stack: `cd bootstrap && terraform init && terraform apply`. Expect `Plan: 0 to add, 4 to import, 0 to change, 0 to destroy`.
- [ ] Verify the post-apply re-plan reports `No changes`.
- [ ] Remove the four `import {}` blocks from `bootstrap/main.tf`, commit as a follow-up. Plan still `No changes`.

### Phase N — each new workload stack

- [ ] HCL drafted in `live/<project>/<component>/<env>/` with `bucket = "<project>-terraform-prod"`, `key = "<component>/<env>/terraform.tfstate"`, `use_lockfile = true`.
- [ ] PR opened. Plan job posts comment. Merge after review.
- [ ] Operator dispatches the apply via Actions → workflow → Run workflow → pick the stack.
- [ ] Subsequent PRs to that stack auto-plan; staging applies don't need reviewer, prod applies pause on the `prod` Environment.

---

## 7. Verification methodology (the smoke test pattern)

Verifying an OIDC setup is non-obvious because most failure modes have similar symptoms (`AccessDenied`). Use this layered approach:

### Layer 1 — structural verification (no AWS calls needed)

Confirm the trust + permissions policies are syntactically correct:

```sh
# IDP exists
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'github')].Arn"

# Roles exist with the expected trust subjects
for role in <project>-tf-plan-readonly <project>-tf-staging-apply <project>-tf-prod-apply; do
  aws iam get-role --role-name "$role" \
    --query 'Role.{Arn:Arn, Trust:AssumeRolePolicyDocument.Statement[0].Condition}'
done

# Inline policies attached
for role in $ROLES; do
  aws iam list-role-policies --role-name "$role"
  aws iam get-role-policy --role-name "$role" --policy-name "$role" \
    --query 'PolicyDocument.Statement[].Sid'
done
```

### Layer 2 — IAM policy simulation (no JWT needed)

Use `aws iam simulate-principal-policy` to dry-run what each role can/can't do without needing a real JWT:

```sh
ROLE="arn:aws:iam::<acct>:role/<project>-tf-plan-readonly"

# Allowed cases — should return 'allowed'
aws iam simulate-principal-policy --policy-source-arn "$ROLE" \
  --action-names s3:GetObject ec2:DescribeInstances \
  --resource-arns "arn:aws:s3:::<project>-terraform-prod/test" "*"

# Denied cases — should return 'implicitDeny'
aws iam simulate-principal-policy --policy-source-arn "$ROLE" \
  --action-names secretsmanager:GetSecretValue iam:CreateRole \
  --resource-arns "arn:aws:secretsmanager:us-west-2:<acct>:secret:test" \
                  "arn:aws:iam::<acct>:role/not-in-scope"
```

This catches missing permissions and over-broad permissions without needing GitHub Actions to fire. **Especially good for testing the no-escalation invariant** (apply role should be denied on out-of-scope `iam:CreateRole`).

### Layer 3 — terraform plan with the role's actual credentials

Temporarily widen the role's trust to allow local-user `sts:AssumeRole`, assume it, run terraform plan, revert. See [the dmair-terraform smoke test approach for the exact script]. This catches AWS provider behaviors that policy simulation can't predict (like the silent `HeadBucket` 403 → "bucket deleted" cascade).

```sh
# Temporarily add yourself to the role's trust policy as a non-OIDC principal
aws iam update-assume-role-policy --role-name <role> --policy-document file://./temp-trust-with-debug-user.json
sleep 12  # IAM propagation
aws sts assume-role --role-arn arn:aws:iam::<acct>:role/<role> --role-session-name debug \
  > /tmp/creds.json

# Set the assumed creds; run terraform with them
export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId /tmp/creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey /tmp/creds.json)
export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken /tmp/creds.json)
terraform -chdir=<stack> plan

# Revert the trust policy IMMEDIATELY after
aws iam update-assume-role-policy --role-name <role> --policy-document file://./clean-trust.json
```

Always pair the widen + revert in the same script so you can't forget to revert.

### Layer 4 — end-to-end via a smoke PR

Open a no-op PR, watch the workflow run, look for `Authenticated as arnId AROA…:GitHubActions` in the `Configure AWS credentials` step's log. That ARN can only exist after a successful OIDC handshake. **This is the conclusive proof.**

Any failure mode shows in the workflow logs:
- `Not authorized to perform: sts:AssumeRoleWithWebIdentity` → trust policy / sub claim mismatch (Layer 1 didn't catch it because trust matches structurally but the `sub` GitHub emits doesn't match the StringLike pattern; rare).
- `Could not retrieve OIDC token` → workflow missing `permissions: id-token: write` (Layer 1 catches by inspection).
- `AccessDenied` on a specific service action → role inherited but permissions gap (Layer 2 catches; sometimes only Layer 4 surfaces obscure ones like `HeadBucket`).

---

## 8. References

- [GitHub Actions OIDC with AWS — official docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [aws-actions/configure-aws-credentials@v4](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform S3 backend + use_lockfile](https://developer.hashicorp.com/terraform/language/settings/backends/s3#use_lockfile)
- [Terraform `import` block — declarative imports](https://developer.hashicorp.com/terraform/language/import)
- [IAM action reference for S3](https://docs.aws.amazon.com/service-authorization/reference/list_amazons3.html)
- [`docs/iam-oidc/README.md`](iam-oidc/README.md) — concrete walkthrough for this repo's OIDC setup
