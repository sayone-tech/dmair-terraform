# GitHub OIDC trust + dmair-backend-staging-deploy IAM role.
#
# The OIDC identity provider is account-wide. We create it here in the
# staging-backend stack because it's the first place that needs it. Future
# stacks (Phase 4 CI/CD will define a sibling terraform-apply role) can
# reference it via `data "aws_iam_openid_connect_provider" "github"` instead
# of recreating it. If a later stack chooses to manage the provider itself,
# move via `terraform state mv`.
#
# Role scope: dmair-backend-staging-deploy is the cross-repo contract role
# for the dmair-backend CI's staging deploy job. It can:
#   - push/pull the dmair-backend ECR repo
#   - read the dmair/staging/app Secrets Manager secret
#   - run an SSM command / start a Session Manager session against the
#     staging EC2 instance
# It CANNOT touch any cms-* / frontend-* / strapi-* resource (deny-by-
# exclusion: no wildcards in the resource ARNs).

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # GitHub's current Actions OIDC thumbprint (2026-05)
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}

data "aws_iam_policy_document" "dmair_backend_staging_deploy_trust" {
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

    # Allow specific refs / environments only — staging-track refs from the
    # dmair-backend repo. See variables.tf var.github_deploy_branches.
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

resource "aws_iam_role" "dmair_backend_staging_deploy" {
  name                 = "dmair-backend-staging-deploy"
  description          = "OIDC role assumed by dmair-backend CI for staging-track deploys"
  assume_role_policy   = data.aws_iam_policy_document.dmair_backend_staging_deploy_trust.json
  max_session_duration = 3600

  tags = {
    Name = "dmair-backend-staging-deploy"
  }
}

data "aws_iam_policy_document" "dmair_backend_staging_deploy_perms" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # required: not resource-scopable
  }

  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid       = "ReadAppSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.app.arn]
  }

  statement {
    sid = "SsmDeployRollEc2"
    actions = [
      "ssm:SendCommand",
      "ssm:StartSession",
      "ssm:DescribeInstanceInformation",
      "ssm:GetCommandInvocation",
    ]
    resources = [
      aws_instance.app.arn,
      # SSM SendCommand also requires document ARNs:
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
    ]
  }
}

resource "aws_iam_role_policy" "dmair_backend_staging_deploy" {
  name   = "dmair-backend-staging-deploy-policy"
  role   = aws_iam_role.dmair_backend_staging_deploy.id
  policy = data.aws_iam_policy_document.dmair_backend_staging_deploy_perms.json
}
