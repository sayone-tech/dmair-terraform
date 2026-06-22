# EC2 instance + Elastic IP for dmair-backend staging.
#
# AMI: latest Ubuntu Server 24.04 LTS ARM64 from Canonical's SSM public
# parameter (the value resolves at apply time; we ignore_changes on `ami`
# so AWS-side AMI updates don't trigger replacement, matching the spec).

data "aws_ssm_parameter" "ubuntu_arm" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.ubuntu_arm.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.key_pair_name # null by default — SSM Session Manager is primary access

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # container needs >1 to reach IMDS
    http_endpoint               = "enabled"
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    aws_region      = var.aws_region
    secret_id       = aws_secretsmanager_secret.app.name
    app_image       = var.app_image
    ecr_registry    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    db_endpoint     = aws_db_instance.postgres.address
    db_name         = var.db_name
    db_username     = var.db_username
    domain          = var.staging_domain
    frontend_origin = var.staging_frontend_origin
  })

  tags = {
    Name = "dmair-staging-ec2"
  }

  lifecycle {
    # AMI updates from Canonical's SSM parameter would otherwise trigger
    # instance replacement on every apply; ignore so changes only happen
    # via deliberate intervention.
    #
    # user_data is ignored after creation (matching the shared modules/ec2
    # convention). It runs ONLY at first boot, and post-boot config is managed
    # out-of-band (CI deploys via `systemctl restart dmair-staging.service`, not
    # by re-running user_data). Without this, edits to user-data.sh show as a
    # perpetual in-place diff that never actually reaches the running box; with
    # user_data_replace_on_change defaulting to false the instance is updated
    # in-place rather than replaced, but ignoring it removes the misleading drift
    # entirely. To intentionally ship new user_data, rebuild the instance
    # (taint / -replace) — a fresh launch always uses the current user-data.sh.
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name = "dmair-staging-eip"
  }

  lifecycle {
    prevent_destroy = true # stable IP — DNS A record at GoDaddy points here
  }
}

data "aws_caller_identity" "current" {}
