# platform/oidc/main.tf
#
# Account-wide foundations for GitHub Actions OIDC integration:
#   1. The GitHub OIDC identity provider (singleton per AWS account).
#   2. Three terraform CI roles (plan-readonly, staging-apply, prod-apply)
#      that PR and main-branch workflow runs assume via web identity.
#
# Managed policies are rendered from policies/*.tpl via modules/iam-policy.
# Trust policies are built inline per-role because they bind specific
# OIDC sub-claim patterns.
#
# Sibling stacks should reference the OIDC provider via:
#   data "aws_iam_openid_connect_provider" "github" {
#     url = "https://token.actions.githubusercontent.com"
#   }
# rather than recreating it.

data "aws_caller_identity" "current" {}

locals {
  repo_sub_prefix = "repo:${var.github_org}/${var.github_repo}"
}

# ----------------------------------------------------------------------------
# GitHub Actions OIDC identity provider (account-wide singleton).
# ----------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # GitHub Actions OIDC root (validated 2026-05)
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}

# ----------------------------------------------------------------------------
# Rendered managed policies for the three terraform CI roles.
# Each template produces one aws_iam_policy via modules/iam-policy.
# ----------------------------------------------------------------------------

module "tf_ci_policies" {
  source      = "../../modules/iam-policy"
  name_prefix = "dmair-terraform"

  policy_templates = [
    "tf_plan_readonly",
    "tf_staging_apply",
    "tf_prod_apply",
  ]

  template_vars = {
    tf_plan_readonly = {
      state_bucket_arn = var.state_bucket_arn
    }
    tf_staging_apply = {
      state_bucket_arn = var.state_bucket_arn
      account_id       = data.aws_caller_identity.current.account_id
      aws_region       = var.aws_region
    }
    tf_prod_apply = {
      state_bucket_arn = var.state_bucket_arn
      account_id       = data.aws_caller_identity.current.account_id
      aws_region       = var.aws_region
    }
  }

  tags = {
    Name = "dmair-terraform-ci"
  }
}

# ----------------------------------------------------------------------------
# Trust policy documents — one per role. Each binds the OIDC provider
# and the sub-claim pattern set for the corresponding role.
# ----------------------------------------------------------------------------

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
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
        "${local.repo_sub_prefix}:${s}*"
      ]
    }
  }
}

data "aws_iam_policy_document" "staging_apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
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

data "aws_iam_policy_document" "prod_apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
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
        for s in var.prod_apply_subjects :
        "${local.repo_sub_prefix}:${s}"
      ]
    }
  }
}

# ----------------------------------------------------------------------------
# The three roles, each composed via modules/iam-role.
# ----------------------------------------------------------------------------

module "plan_readonly_role" {
  source             = "../../modules/iam-role"
  role_name          = "dmair-terraform-plan-readonly"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
  policy_arns_map = {
    tf_plan_readonly = module.tf_ci_policies.policy_arns_map["tf_plan_readonly"]
  }
  tags = { Name = "dmair-terraform-plan-readonly" }
}

module "staging_apply_role" {
  source             = "../../modules/iam-role"
  role_name          = "dmair-terraform-staging-apply"
  assume_role_policy = data.aws_iam_policy_document.staging_apply_trust.json
  policy_arns_map = {
    tf_staging_apply = module.tf_ci_policies.policy_arns_map["tf_staging_apply"]
  }
  tags = { Name = "dmair-terraform-staging-apply" }
}

module "prod_apply_role" {
  source             = "../../modules/iam-role"
  role_name          = "dmair-terraform-prod-apply"
  assume_role_policy = data.aws_iam_policy_document.prod_apply_trust.json
  policy_arns_map = {
    tf_prod_apply = module.tf_ci_policies.policy_arns_map["tf_prod_apply"]
  }
  tags = { Name = "dmair-terraform-prod-apply" }
}
