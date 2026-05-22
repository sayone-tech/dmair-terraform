# Plan 01-01 — DevOps Runbook: Capture Live State of `dmair-terraform-prod`

**Status:** Code-only completion deferred this plan's two tasks (one human-action, one AWS CLI capture) to DevOps. This runbook is what DevOps needs to execute.

**Why a runbook instead of Claude-executed:** The user opted for a code-only-then-DevOps workflow — code lands here in feature/aws-deployment; DevOps runs all AWS-side commands. See [01-01-PLAN.md](./01-01-PLAN.md) for the original plan spec.

---

## Task 1 — Environment preconditions (human-action gate)

### What needs to be true

- Terraform CLI installed and on PATH, version `>= 1.10` (workstation user already has v1.15.3; verify your own).
- AWS named profile `dmair` exists in `~/.aws/credentials`.
- For **this plan's read-only captures**, the `dmair` profile can point at a read-capable identity (e.g. the existing `dmair-view` IAM user works). The captures below are all `s3api Get*` / `dynamodb describe-table` / `sts get-caller-identity`.
- **For plan 01-02 onward** (terraform apply against bootstrap, terraform init -reconfigure against the three live stacks), the `dmair` profile must resolve to a write-capable identity with at minimum:
  - `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on `arn:aws:s3:::dmair-terraform-prod` and `arn:aws:s3:::dmair-terraform-prod/*`
  - `sts:GetCallerIdentity`
  (Plan 01-01 task 1 originally listed `PutBucketTagging` + `dynamodb:CreateTable/UpdateTable/TagResource`. Those were leftover from the now-superseded DynamoDB-lock-table approach (quick-task 260520-ntp, 2026-05-20). They are no longer needed — the use_lockfile mechanism writes a `.tflock` sentinel object via the same S3 perms above.)

### Verification commands

Run these from any shell:

```sh
terraform version
# expected: Terraform vX.Y.Z where X.Y.Z >= 1.10.0

aws configure list-profiles
# expected: 'dmair' present

aws --profile dmair sts get-caller-identity
# expected: exits 0 with account 071297531943
# UserId/Arn MUST NOT match dmair-view if you intend to also run plan 01-02 onward;
# for plan 01-01 read-only captures dmair-view is sufficient.

aws --profile dmair s3api get-bucket-versioning --bucket dmair-terraform-prod --region us-west-2
# expected: exits 0 (no AccessDenied). Body may be empty if versioning is unset.
```

If any of the four fail, fix before continuing to Task 2.

---

## Task 2 — Capture live AWS-side configuration

Run the eight commands below verbatim from any shell. Paste each command's exit code and full stdout/stderr into [01-LIVE-STATE-SNAPSHOT.md](./01-LIVE-STATE-SNAPSHOT.md) (template already created with placeholders). For commands returning non-zero with errors like `ServerSideEncryptionConfigurationNotFoundError`, `NoSuchPublicAccessBlockConfiguration`, `NoSuchTagSet`, `NoSuchBucketPolicy`, `NoSuchLifecycleConfiguration`, `NoSuchBucketLoggingStatus` — **record the error verbatim**; the error is a valid live-state value meaning "configuration unset".

### Required captures (load-bearing — these become HCL literals in plan 01-02)

```sh
# 1. Versioning
aws --profile dmair s3api get-bucket-versioning \
    --bucket dmair-terraform-prod --region us-west-2

# 2. Server-side encryption
aws --profile dmair s3api get-bucket-encryption \
    --bucket dmair-terraform-prod --region us-west-2

# 3. Public access block
aws --profile dmair s3api get-public-access-block \
    --bucket dmair-terraform-prod --region us-west-2

# 4. Tagging
aws --profile dmair s3api get-bucket-tagging \
    --bucket dmair-terraform-prod --region us-west-2
```

### Informational captures (drift-surface awareness; not encoded in HCL)

```sh
# 5. Bucket policy (likely NoSuchBucketPolicy — bootstrap stack does NOT manage a bucket policy per D-04)
aws --profile dmair s3api get-bucket-policy \
    --bucket dmair-terraform-prod --region us-west-2

# 6. Lifecycle configuration
aws --profile dmair s3api get-bucket-lifecycle-configuration \
    --bucket dmair-terraform-prod --region us-west-2

# 7. Access logging
aws --profile dmair s3api get-bucket-logging \
    --bucket dmair-terraform-prod --region us-west-2
```

### Greenfield confirmation

```sh
# 8. Confirm legacy DynamoDB lock table does NOT exist (greenfield assumption)
aws --profile dmair dynamodb describe-table \
    --table-name dmair-terraform-locks --region us-west-2
# expected: ResourceNotFoundException
```

---

## After capture: fill in 01-LIVE-STATE-SNAPSHOT.md

Open [01-LIVE-STATE-SNAPSHOT.md](./01-LIVE-STATE-SNAPSHOT.md) (template already committed). For each numbered capture above, paste the full JSON or error text into the matching fenced code block. Then fill in the **HCL Translation Decisions** table at the bottom — that table feeds plan 01-02's `bootstrap/main.tf` TODOs directly.

Translation rules (from 01-RESEARCH.md §Code Examples §Example 1):

| AWS CLI field | HCL argument |
|---|---|
| `get-bucket-versioning` → `.Status` (`"Enabled"` / `"Suspended"`) | `aws_s3_bucket_versioning.this.versioning_configuration.status` |
| empty body | `status = "Disabled"` (omit `versioning_configuration` is wrong — declare `Disabled` explicitly) |
| `get-bucket-encryption` → `.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm` | `aws_s3_bucket_server_side_encryption_configuration.this.rule.apply_server_side_encryption_by_default.sse_algorithm` |
| `get-bucket-encryption` → `.Rules[0].BucketKeyEnabled` (`true`/`false`) | declare `bucket_key_enabled = true` inside the `rule` block ONLY if AWS shows `true`; otherwise omit (default is false) |
| `get-bucket-encryption` SSEAlgorithm = `aws:kms` | also add `kms_master_key_id = "<arn>"` inside `apply_server_side_encryption_by_default` |
| `get-public-access-block` → `.PublicAccessBlockConfiguration.{BlockPublicAcls,BlockPublicPolicy,IgnorePublicAcls,RestrictPublicBuckets}` | `aws_s3_bucket_public_access_block.this.{block_public_acls,block_public_policy,ignore_public_acls,restrict_public_buckets}` |
| `get-bucket-tagging` → `.TagSet` (array of `{Key,Value}`) | `aws_s3_bucket.this.tags = { "<Key>" = "<Value>", ... }`. If `NoSuchTagSet`, OMIT the `tags = ...` argument entirely. |

## After filling the snapshot

1. Commit `.planning/phases/01-bootstrap-state-backend/01-LIVE-STATE-SNAPSHOT.md` with message:
   `docs(BOOTSTRAP-01): capture live state of dmair-terraform-prod`
2. Update [01-01-SUMMARY.md](./01-01-SUMMARY.md) — change the **Status** line from `code-only-complete` to `complete` and fill the **DevOps results** section.
3. Proceed to plan 01-02 — open [01-02-PLAN.md](./01-02-PLAN.md), open `bootstrap/main.tf`, and replace the `# TODO from 01-LIVE-STATE-SNAPSHOT.md §HCL Translation Decisions: <field>` markers with the literal values from the snapshot.
