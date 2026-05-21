# ci/main.tf — IAM roles assumed by GitHub Actions for the dmair-terraform CI.
#
# Three roles:
#   1. dmair-terraform-plan-readonly  — assumed on PRs and push-to-main; can
#      terraform plan against every stack but cannot write or destroy.
#   2. dmair-terraform-staging-apply  — assumed on push-to-main; can apply
#      live/dmair/staging/* stacks (the staging frontend + staging backend).
#   3. dmair-terraform-prod-apply     — assumed only when GitHub Actions
#      runs in the 'prod' Environment (required reviewers gate); can apply
#      bootstrap/, live/dmair/prod/*. No iam:Create* on roles it does not
#      already own (CICD-01 #3 — no-escalation invariant).
#
# OIDC identity provider is account-wide and was created in Phase 3
# (live/dmair/staging/backend/oidc.tf). We `data` it here. If the staging
# backend stack is ever destroyed, the OIDC provider needs to be moved to
# this stack via `terraform state mv` first to avoid breaking trust.
# Tracked in OIDC.md §Future improvements.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

# Convenience — repo-scoped trust subject prefix.
locals {
  repo_sub_prefix = "repo:${var.github_org}/${var.github_repo}"
}

# ----------------------------------------------------------------------------
# Role 1 — dmair-terraform-plan-readonly
# ----------------------------------------------------------------------------

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for s in var.plan_subjects :
        "${local.repo_sub_prefix}:${s}*" # `*` because PR subs include the PR number
      ]
    }
  }
}

resource "aws_iam_role" "plan_readonly" {
  name                 = "dmair-terraform-plan-readonly"
  description          = "GitHub Actions assumes this on PRs to terraform plan against every stack (read-only)."
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "plan_perms" {
  # State bucket read (terraform plan reads the state from S3 and the
  # tflock sentinel must be writable for the lock cycle).
  statement {
    sid     = "StateBucketRead"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      var.state_bucket_arn,
      "${var.state_bucket_arn}/*",
    ]
  }

  # Plan still acquires + releases the .tflock object during refresh.
  statement {
    sid       = "StateLockfileRw"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*.tflock"]
  }

  # Refresh — read every resource type the stacks manage.
  statement {
    sid = "DescribeAllForRefresh"
    actions = [
      # Networking
      "ec2:Describe*",
      "ec2:Get*",
      # Compute
      "ec2:DescribeInstances",
      "ec2:DescribeAddresses",
      # RDS
      "rds:Describe*",
      "rds:ListTagsForResource",
      # ECR
      "ecr:Describe*",
      "ecr:List*",
      "ecr:Get*",
      "ecr:BatchGetImage",
      # Secrets — Describe only, NOT Get (secret values stay opaque to plan).
      "secretsmanager:Describe*",
      "secretsmanager:ListSecret*",
      "secretsmanager:GetResourcePolicy",
      # IAM — read-only on roles + policies + providers.
      "iam:Get*",
      "iam:List*",
      # CloudFront
      "cloudfront:Get*",
      "cloudfront:List*",
      # S3 — bucket configuration reads.
      "s3:GetBucket*",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetObjectTagging",
      "s3:ListAllMyBuckets",
      # Logs
      "logs:Describe*",
      "logs:List*",
      # SSM
      "ssm:Get*",
      "ssm:Describe*",
      "ssm:List*",
      # Route53
      "route53:Get*",
      "route53:List*",
      # ACM
      "acm:Describe*",
      "acm:List*",
      # Budgets
      "budgets:Describe*",
      "budgets:View*",
      # STS — sanity check
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan_readonly" {
  name   = "dmair-terraform-plan-readonly-policy"
  role   = aws_iam_role.plan_readonly.id
  policy = data.aws_iam_policy_document.plan_perms.json
}

# ----------------------------------------------------------------------------
# Role 2 — dmair-terraform-staging-apply
# ----------------------------------------------------------------------------

data "aws_iam_policy_document" "staging_apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for s in var.staging_apply_subjects :
        "${local.repo_sub_prefix}:${s}"
      ]
    }
  }
}

resource "aws_iam_role" "staging_apply" {
  name                 = "dmair-terraform-staging-apply"
  description          = "GitHub Actions assumes this on push-to-main to apply live/dmair/staging/* stacks."
  assume_role_policy   = data.aws_iam_policy_document.staging_apply_trust.json
  max_session_duration = 3600
}

# Staging apply inherits the plan-readonly permission set, plus broad
# read/write/delete on resources tagged Environment=staging OR explicitly
# matching the staging stack ARNs.
data "aws_iam_policy_document" "staging_apply_perms" {
  source_policy_documents = [data.aws_iam_policy_document.plan_perms.json]

  # State write
  statement {
    sid       = "StateBucketWrite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/staging/*", "${var.state_bucket_arn}/frontend/staging/*"]
  }

  # EC2 / VPC mutations — scoped to staging tag.
  statement {
    sid = "Ec2VpcStagingMutate"
    actions = [
      "ec2:Create*",
      "ec2:Delete*",
      "ec2:Modify*",
      "ec2:Associate*",
      "ec2:Disassociate*",
      "ec2:Attach*",
      "ec2:Detach*",
      "ec2:Authorize*",
      "ec2:Revoke*",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:Start*",
      "ec2:Stop*",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = ["staging"]
    }
  }

  # RDS / Secrets / ECR / Logs — scoped to staging via name prefix.
  statement {
    sid = "RdsStagingMutate"
    actions = [
      "rds:Create*",
      "rds:Delete*",
      "rds:Modify*",
      "rds:Reboot*",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
    ]
    resources = ["arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:dmair-staging*",
      "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subgrp:dmair-staging*",
    ]
  }

  statement {
    sid = "SecretsStagingMutate"
    actions = [
      "secretsmanager:Create*",
      "secretsmanager:Update*",
      "secretsmanager:Delete*",
      "secretsmanager:Put*",
      "secretsmanager:Restore*",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:dmair/staging/*"]
  }

  statement {
    sid = "EcrDmairBackendMutate"
    actions = [
      "ecr:Create*",
      "ecr:Delete*",
      "ecr:Put*",
      "ecr:Set*",
      "ecr:Tag*",
      "ecr:Untag*",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/dmair-backend"]
  }

  statement {
    sid = "LogsStagingMutate"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/dmair/staging*"]
  }

  # IAM mutate — staging-tagged or staging-named roles/policies/profiles
  # only. NO iam:CreateUser, NO iam:Create* on roles outside the staging
  # name prefix (CICD-01 #3 — no escalation).
  statement {
    sid = "IamStagingMutate"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dmair-staging-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dmair-backend-staging-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/dmair-staging-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/dmair-staging-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/dmair-backend-staging-*",
    ]
  }

  # Budgets — scoped to staging budget name.
  statement {
    sid = "BudgetsStagingMutate"
    actions = [
      "budgets:CreateBudget",
      "budgets:ModifyBudget",
      "budgets:DeleteBudget",
    ]
    resources = ["arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/dmair-staging-*"]
  }
}

resource "aws_iam_role_policy" "staging_apply" {
  name   = "dmair-terraform-staging-apply-policy"
  role   = aws_iam_role.staging_apply.id
  policy = data.aws_iam_policy_document.staging_apply_perms.json
}

# ----------------------------------------------------------------------------
# Role 3 — dmair-terraform-prod-apply
# ----------------------------------------------------------------------------

data "aws_iam_policy_document" "prod_apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Sub claim restricted to GitHub Environment = 'prod' — required
    # reviewers gate runs here. The Environment in GitHub Actions is set
    # via `environment: prod` in the workflow job.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for s in var.prod_apply_subjects :
        "${local.repo_sub_prefix}:${s}"
      ]
    }
  }
}

resource "aws_iam_role" "prod_apply" {
  name                 = "dmair-terraform-prod-apply"
  description          = "GitHub Actions assumes this only from the 'prod' Environment to apply prod + bootstrap stacks. Required-reviewers gated."
  assume_role_policy   = data.aws_iam_policy_document.prod_apply_trust.json
  max_session_duration = 3600
}

# Prod apply is the broadest role — it can apply bootstrap/ (the state
# backend itself) and live/dmair/prod/* (strapi, frontend). Required
# reviewers gate at the GitHub Environment level is the primary safety
# control; IAM scoping is belt-and-suspenders.
data "aws_iam_policy_document" "prod_apply_perms" {
  source_policy_documents = [data.aws_iam_policy_document.plan_perms.json]

  statement {
    sid       = "StateBucketWriteAll"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*"]
  }

  statement {
    sid       = "BootstrapBucketManage"
    actions   = ["s3:PutBucket*", "s3:DeleteBucket*", "s3:PutEncryptionConfiguration", "s3:PutLifecycleConfiguration", "s3:PutBucketPolicy", "s3:PutBucketTagging", "s3:PutBucketVersioning", "s3:PutPublicAccessBlock"]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid = "Ec2VpcProdMutate"
    actions = [
      "ec2:Create*",
      "ec2:Delete*",
      "ec2:Modify*",
      "ec2:Associate*",
      "ec2:Disassociate*",
      "ec2:Attach*",
      "ec2:Detach*",
      "ec2:Authorize*",
      "ec2:Revoke*",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:Start*",
      "ec2:Stop*",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudfrontProdMutate"
    actions = [
      "cloudfront:Create*",
      "cloudfront:Update*",
      "cloudfront:Delete*",
      "cloudfront:Tag*",
      "cloudfront:Untag*",
      "cloudfront:CreateInvalidation",
    ]
    resources = ["*"]
  }

  statement {
    sid = "S3ProdMutate"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucket*",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutPublicAccessBlock",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["*"]
  }

  statement {
    sid = "SecretsProdMutate"
    actions = [
      "secretsmanager:Create*",
      "secretsmanager:Update*",
      "secretsmanager:Delete*",
      "secretsmanager:Put*",
      "secretsmanager:Restore*",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
    ]
    resources = ["*"]
  }

  # IAM mutate for prod — scoped by name to existing prod-related prefixes
  # (frontend-*, strapi-*, dmair-prod-*, github-actions-*). Still no
  # iam:CreateUser without restriction; iam:Create* on roles allowed only
  # within these prefixes (CICD-01 #3 — no escalation outside scope).
  statement {
    sid = "IamProdMutate"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:UpdateUser",
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:PutUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:TagUser",
      "iam:UntagUser",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/strapi-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/frontend-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dmair-prod-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cms-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/strapi-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/dmair-prod-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/github-actions-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/strapi-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/frontend-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/strapi-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/frontend-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/dmair-prod-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-*",
    ]
  }

  statement {
    sid       = "EcrProdMutate"
    actions   = ["ecr:Create*", "ecr:Delete*", "ecr:Put*", "ecr:Set*", "ecr:Tag*", "ecr:Untag*"]
    resources = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*"]
  }

  statement {
    sid       = "LogsProdMutate"
    actions   = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:TagLogGroup", "logs:UntagLogGroup"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "prod_apply" {
  name   = "dmair-terraform-prod-apply-policy"
  role   = aws_iam_role.prod_apply.id
  policy = data.aws_iam_policy_document.prod_apply_perms.json
}
