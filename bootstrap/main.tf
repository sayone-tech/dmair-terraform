# bootstrap/main.tf — adopts the pre-existing dmair-terraform-prod S3 bucket into IaC.
# Four resources + four declarative `import {}` blocks. After plan 01-02 Task 3
# (operator-only: terraform init && apply) succeeds with zero-change plan, the
# four `import {}` blocks must be removed in a follow-up commit per plan 01-02
# Task 4 (HashiCorp best practice — RESEARCH §Pitfall 7).
#
# Literal values were captured from live AWS state on 2026-05-22 via the
# snapshot procedure in .planning/phases/01-bootstrap-state-backend/01-01-DEVOPS-RUNBOOK.md.
# Source of truth: .planning/phases/01-bootstrap-state-backend/01-LIVE-STATE-SNAPSHOT.md
# §HCL Translation Decisions.

resource "aws_s3_bucket" "this" {
  bucket = "dmair-terraform-prod"

  # Live state has no tags (NoSuchTagSet). `tags` argument intentionally omitted
  # — declaring it as an empty map would cause terraform to call PutBucketTagging
  # with an empty TagSet, which is a behavior change vs the current AWS state.
}

import {
  to = aws_s3_bucket.this
  id = "dmair-terraform-prod"
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    # Live state: GetBucketVersioning returned an empty body — versioning has never
    # been configured. "Suspended" is the canonical Terraform value that matches
    # the AWS API's empty-response default and produces a zero-change plan on import.
    status = "Suspended"
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
      # Live state: AES256 (SSE-S3). No KMS key.
      sse_algorithm = "AES256"
    }
    # Live state: BucketKeyEnabled = true.
    bucket_key_enabled = true
  }
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.this
  id = "dmair-terraform-prod"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  # Live state: all four block flags = true (the AWS-recommended default for
  # private buckets — confirmed by GetPublicAccessBlock).
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

import {
  to = aws_s3_bucket_public_access_block.this
  id = "dmair-terraform-prod"
}
