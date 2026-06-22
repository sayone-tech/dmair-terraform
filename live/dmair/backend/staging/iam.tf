# IAM for the EC2 instance — pulls images from ECR, reads the app secret,
# writes container logs to CloudWatch, registers with SSM for Session
# Manager / Run Command access. NO inbound SSH; SSM is the access path.
#
# Permission policy is rendered from policies/ec2_app_runtime.tpl via
# modules/iam-policy. Role + attachments are composed via modules/iam-role.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

module "ec2_runtime_policy" {
  source           = "../../../../modules/iam-policy"
  name_prefix      = "dmair-staging-ec2"
  policy_templates = ["ec2_app_runtime"]

  template_vars = {
    ec2_app_runtime = {
      ecr_repository_arn = aws_ecr_repository.app.arn
      app_secret_arn     = aws_secretsmanager_secret.app.arn
      log_group_arn      = aws_cloudwatch_log_group.staging.arn

      # Phase 13 ingest refresh-token secret. MailboxSecretService creates this
      # secret at first Connect, so Secrets Manager appends a random suffix —
      # grant on a name-prefix wildcard ARN. The rendered policy grants
      # DeleteSecret in addition to Get/Put/Create/Describe because the app
      # deletes this secret when a mailbox is disconnected; the runtime role
      # therefore needs Delete on this prefix (the wildcard scopes it to the
      # ingest secret only — never the consolidated dmair/staging/app secret).
      ingest_refresh_token_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:dmair/ingest/google-refresh-token-*"
    }
  }

  tags = { Name = "dmair-staging-ec2" }
}

module "ec2_role" {
  source             = "../../../../modules/iam-role"
  role_name          = "dmair-staging-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  policy_arns_map = {
    runtime = module.ec2_runtime_policy.policy_arns_map["ec2_app_runtime"]
    ssm     = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = { Name = "dmair-staging-ec2-role" }
}

resource "aws_iam_instance_profile" "ec2" {
  name = "dmair-staging-ec2-profile"
  role = module.ec2_role.role_name
}
