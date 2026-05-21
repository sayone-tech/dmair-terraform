# Phase 1: dmair-terraform-prod Live State Snapshot

**Status:** TEMPLATE — pending DevOps execution per [01-01-DEVOPS-RUNBOOK.md](./01-01-DEVOPS-RUNBOOK.md)
**Captured by:** _(DevOps name)_
**Capture date:** _(YYYY-MM-DD)_
**AWS account:** _(should resolve to 071297531943)_
**Identity used:** _(arn from `aws sts get-caller-identity`)_

---

## Capture 1 — `get-bucket-versioning`

Command:
```sh
aws --profile dmair s3api get-bucket-versioning --bucket dmair-terraform-prod --region us-west-2
```

Exit code: _(0 / N)_

Output:
```json
TODO_DEVOPS: paste full stdout or error here
```

---

## Capture 2 — `get-bucket-encryption`

Command:
```sh
aws --profile dmair s3api get-bucket-encryption --bucket dmair-terraform-prod --region us-west-2
```

Exit code: _(0 / N)_

Output:
```json
TODO_DEVOPS: paste full stdout or error here
```

---

## Capture 3 — `get-public-access-block`

Command:
```sh
aws --profile dmair s3api get-public-access-block --bucket dmair-terraform-prod --region us-west-2
```

Exit code: _(0 / N)_

Output:
```json
TODO_DEVOPS: paste full stdout or error here
```

---

## Capture 4 — `get-bucket-tagging`

Command:
```sh
aws --profile dmair s3api get-bucket-tagging --bucket dmair-terraform-prod --region us-west-2
```

Exit code: _(0 / N — NoSuchTagSet is valid)_

Output:
```json
TODO_DEVOPS: paste full stdout or error here
```

---

## Capture 5 — `get-bucket-policy` (informational)

Command:
```sh
aws --profile dmair s3api get-bucket-policy --bucket dmair-terraform-prod --region us-west-2
```

Exit code: _(0 / N — NoSuchBucketPolicy expected per D-04)_

Output:
```json
TODO_DEVOPS: paste full stdout or error here
```

---

## Capture 6 — `get-bucket-lifecycle-configuration` (informational)

Command:
```sh
aws --profile dmair s3api get-bucket-lifecycle-configuration --bucket dmair-terraform-prod --region us-west-2
```

Exit code: _(0 / N)_

Output:
```json
TODO_DEVOPS: paste full stdout or error here
```

---

## Capture 7 — `get-bucket-logging` (informational)

Command:
```sh
aws --profile dmair s3api get-bucket-logging --bucket dmair-terraform-prod --region us-west-2
```

Exit code: _(0 / N)_

Output:
```json
TODO_DEVOPS: paste full stdout or error here
```

---

## Capture 8 — `dynamodb describe-table dmair-terraform-locks` (greenfield confirmation)

Command:
```sh
aws --profile dmair dynamodb describe-table --table-name dmair-terraform-locks --region us-west-2
```

Exit code: _(expected non-zero with ResourceNotFoundException)_

Output:
```text
TODO_DEVOPS: paste full stdout or error here. Expected: ResourceNotFoundException — table dmair-terraform-locks does not exist (use_lockfile uses S3-native locking, no DynamoDB table is created).
```

---

## HCL Translation Decisions

These rows are the load-bearing handoff to `bootstrap/main.tf` (plan 01-02). Fill in **Literal value** from the captures above per the translation table in [01-01-DEVOPS-RUNBOOK.md](./01-01-DEVOPS-RUNBOOK.md#after-capture-fill-in-01-live-state-snapshotmd).

| Source capture | HCL resource.argument | Literal value to paste |
|---|---|---|
| Capture 1 `.Status` | `aws_s3_bucket_versioning.this.versioning_configuration.status` | `TODO_DEVOPS: "Enabled" \| "Suspended" \| "Disabled"` |
| Capture 2 `.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm` | `aws_s3_bucket_server_side_encryption_configuration.this.rule.apply_server_side_encryption_by_default.sse_algorithm` | `TODO_DEVOPS: "AES256" \| "aws:kms"` |
| Capture 2 `.Rules[0].BucketKeyEnabled` | `aws_s3_bucket_server_side_encryption_configuration.this.rule.bucket_key_enabled` | `TODO_DEVOPS: true \| (omit if false)` |
| Capture 2 `.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID` (only if SSEAlgorithm is aws:kms) | `...apply_server_side_encryption_by_default.kms_master_key_id` | `TODO_DEVOPS: "<arn>" \| (omit if AES256)` |
| Capture 3 `.PublicAccessBlockConfiguration.BlockPublicAcls` | `aws_s3_bucket_public_access_block.this.block_public_acls` | `TODO_DEVOPS: true \| false` |
| Capture 3 `.PublicAccessBlockConfiguration.BlockPublicPolicy` | `aws_s3_bucket_public_access_block.this.block_public_policy` | `TODO_DEVOPS: true \| false` |
| Capture 3 `.PublicAccessBlockConfiguration.IgnorePublicAcls` | `aws_s3_bucket_public_access_block.this.ignore_public_acls` | `TODO_DEVOPS: true \| false` |
| Capture 3 `.PublicAccessBlockConfiguration.RestrictPublicBuckets` | `aws_s3_bucket_public_access_block.this.restrict_public_buckets` | `TODO_DEVOPS: true \| false` |
| Capture 4 `.TagSet` | `aws_s3_bucket.this.tags` | `TODO_DEVOPS: { "Key1" = "Val1", ... } \| (omit `tags` argument entirely if NoSuchTagSet)` |

### Drift-surface awareness (informational; not encoded in HCL)

- **Bucket policy** (capture 5): _(record present/absent here)_ — per D-04, bucket policy stays out of IaC.
- **Lifecycle** (capture 6): _(record present/absent here)_ — per D-04, lifecycle stays out of IaC.
- **Access logging** (capture 7): _(record present/absent here)_ — per D-04, logging stays out of IaC.
