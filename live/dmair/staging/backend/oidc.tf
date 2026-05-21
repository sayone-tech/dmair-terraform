# dmair-backend-staging-deploy — cross-repo OIDC contract.
#
# The GitHub OIDC identity provider itself is managed in platform/oidc/
# (account-wide singleton); we data-source it here. Apply platform/oidc/
# BEFORE applying this stack.
#
# Role scope (STAGING-03 deny-by-exclusion — no resource wildcards):
#   - ECR auth + push/pull on the dmair-backend repo only
#   - Secrets Manager GetSecretValue on dmair/staging/app only
#   - SSM SendCommand / StartSession / Describe* on the staging EC2
#     instance only, plus the AWS-RunShellScript document
#
# Permission policy rendered from policies/github_app_deploy.tpl.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "dmair_backend_staging_deploy_trust" {
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

    # Restrict to staging-track refs from the dmair-backend repo only.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for ref in var.github_deploy_branches :
        "repo:${var.github_org}/${var.github_repo}:${ref}"
      ]
    }
  }
}

module "dmair_backend_staging_deploy_policy" {
  source           = "../../../../modules/iam-policy"
  name_prefix      = "dmair-backend-staging-deploy"
  policy_templates = ["github_app_deploy"]

  template_vars = {
    github_app_deploy = {
      ecr_repository_arn = aws_ecr_repository.app.arn
      app_secret_arn     = aws_secretsmanager_secret.app.arn
      ssm_resource_arns = [
        aws_instance.app.arn,
        "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
      ]
    }
  }

  tags = { Name = "dmair-backend-staging-deploy" }
}

module "dmair_backend_staging_deploy_role" {
  source             = "../../../../modules/iam-role"
  role_name          = "dmair-backend-staging-deploy"
  assume_role_policy = data.aws_iam_policy_document.dmair_backend_staging_deploy_trust.json

  policy_arns_map = {
    deploy = module.dmair_backend_staging_deploy_policy.policy_arns_map["github_app_deploy"]
  }

  tags = { Name = "dmair-backend-staging-deploy" }
}
