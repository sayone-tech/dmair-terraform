# bootstrap/main.tf — adopts the pre-existing dmair-terraform-prod S3 bucket into IaC.
# Four resources + four declarative `import {}` blocks. After plan 01-02 Task 3
# (operator-only: terraform init && apply) succeeds with zero-change plan, the
# four `import {}` blocks must be removed in a follow-up commit per plan 01-02
# Task 4 (HashiCorp best practice — RESEARCH §Pitfall 7).
#
# Literal values marked TODO_DEVOPS_FROM_SNAPSHOT come from
# .planning/phases/01-bootstrap-state-backend/01-LIVE-STATE-SNAPSHOT.md
# §HCL Translation Decisions. Replace before running terraform init/apply.

resource "aws_s3_bucket" "this" {
  bucket = "dmair-terraform-prod"

  # TODO_DEVOPS_FROM_SNAPSHOT: if 01-LIVE-STATE-SNAPSHOT.md capture 4 returned
  # tags, add tags = { "Key1" = "Val1", ... } below. If NoSuchTagSet, leave
  # this comment in place and OMIT the tags argument entirely (per Pitfall 8).
}

import {
  to = aws_s3_bucket.this
  id = "dmair-terraform-prod"
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    # TODO_DEVOPS_FROM_SNAPSHOT: capture 1 .Status — "Enabled" | "Suspended" | "Disabled".
    # WARNING (Pitfall 3): "Disabled" is irreversible once written to AWS.
    # Mirror live AWS exactly — do NOT guess.
    status = "TODO_DEVOPS_FROM_SNAPSHOT"
  }
}

import {
  to = aws_s3_bucket_versioning.this
  id = "dmair-terraform-prod"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      # TODO_DEVOPS_FROM_SNAPSHOT: capture 2 .Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm
      # — typically "AES256". If "aws:kms", also add kms_master_key_id = "<arn>" below.
      sse_algorithm = "TODO_DEVOPS_FROM_SNAPSHOT"
    }
    # TODO_DEVOPS_FROM_SNAPSHOT: capture 2 .Rules[0].BucketKeyEnabled — if true,
    # add `bucket_key_enabled = true` on the line above. If false or absent, omit.
  }
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.this
  id = "dmair-terraform-prod"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  # TODO_DEVOPS_FROM_SNAPSHOT: capture 3 .PublicAccessBlockConfiguration.* —
  # the four bools below are AWS-recommended defaults. Mirror live AWS exactly;
  # if capture 3 returned NoSuchPublicAccessBlockConfiguration, STOP and consult
  # plan 01-02 Task 2 (deviation requires sign-off per D-03).
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

import {
  to = aws_s3_bucket_public_access_block.this
  id = "dmair-terraform-prod"
}
