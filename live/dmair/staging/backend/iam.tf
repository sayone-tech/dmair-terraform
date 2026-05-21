# IAM for the EC2 instance — pulls images from ECR, reads the app secret,
# writes container logs to CloudWatch, registers with SSM for Session
# Manager / Run Command access. NO inbound SSH; SSM is the access path.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "dmair-staging-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name = "dmair-staging-ec2-role"
  }
}

data "aws_iam_policy_document" "ec2_perms" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPull"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid       = "ReadAppSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.app.arn]
  }

  statement {
    sid = "WriteLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.staging.arn}:*"]
  }
}

resource "aws_iam_role_policy" "ec2" {
  name   = "dmair-staging-ec2-policy"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_perms.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "dmair-staging-ec2-profile"
  role = aws_iam_role.ec2.name
}

# AWS-managed SSM policy so the box registers with SSM (Session Manager,
# Run Command). Eliminates the need for inbound port 22.
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
