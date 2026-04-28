data "aws_ami" "this" {
  count       = var.EC2_AMI == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = [var.EC2_AMI_FILTER != "" ? var.EC2_AMI_FILTER : "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_instance" "app_server" {
  ami                    = var.EC2_AMI != "" ? var.EC2_AMI : data.aws_ami.this[0].id
  instance_type          = var.EC2_INSTANCE_TYPE
  key_name               = var.EC2_PRIVATE_KEY != "" ? var.EC2_PRIVATE_KEY : null
  vpc_security_group_ids = [var.EC2_SG_ID]
  iam_instance_profile   = var.IAM_PROFILE
  availability_zone      = var.EC2_AZ != "" ? var.EC2_AZ : data.aws_availability_zones.available.names[0]

  user_data = var.EC2_USER_DATA_CONTENT != "" ? var.EC2_USER_DATA_CONTENT : null

  root_block_device {
    volume_type = var.EC2_ROOT_VOLUME_TYPE
    volume_size = var.EC2_ROOT_VOLUME_SIZE
    encrypted   = true
  }

  credit_specification {
    cpu_credits = var.EC2_CPU_CREDITS
  }

  tags = {
    Name = "${var.App_Name}-${var.Env_Type}"
  }

  lifecycle {
    ignore_changes = [
      user_data,
      associate_public_ip_address,
      availability_zone,
      ami,
      key_name
    ]
    prevent_destroy = true
  }
}
