resource "aws_security_group" "sg_ec2_defaults" {
  count       = 1
  name        = "${var.App_Name}-${var.Env_Type}"
  description = "Allow TLS/SSH inbound traffic"

  lifecycle {
    ignore_changes = [ingress]
  }

  # Default ingress rules (when use_default_rules is true)
  dynamic "ingress" {
    for_each = var.use_default_rules ? concat(
      [
        {
          description      = "HTTP connection from Web"
          from_port        = 80
          to_port          = 80
          protocol         = "tcp"
          cidr_blocks      = ["0.0.0.0/0"]
          ipv6_cidr_blocks = ["::/0"]
          security_groups  = []
        },
        {
          description      = "HTTPS connection from Web"
          from_port        = 443
          to_port          = 443
          protocol         = "tcp"
          cidr_blocks      = ["0.0.0.0/0"]
          ipv6_cidr_blocks = ["::/0"]
          security_groups  = []
        },
        {
          description      = "Ssh connection to EC2 From Local"
          from_port        = 22
          to_port          = 22
          protocol         = "tcp"
          cidr_blocks      = ["115.245.232.43/32"]
          ipv6_cidr_blocks = []
          security_groups  = []
        },
        {
          description      = "SSH connection to EC2 from GitHub Actions"
          from_port        = 22
          to_port          = 22
          protocol         = "tcp"
          cidr_blocks      = [var.Github_Actions_IP]
          ipv6_cidr_blocks = []
          security_groups  = []
        }
      ],
      var.Jenkins_IP != "" ? [{
        description      = "SSH connection to EC2 from Jenkins"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = [var.Jenkins_IP]
        ipv6_cidr_blocks = []
        security_groups  = []
      }] : []
    ) : []


    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      security_groups  = ingress.value.security_groups
    }
  }

  # Custom ingress rules (when use_default_rules is false)
  dynamic "ingress" {
    for_each = var.use_default_rules ? [] : var.ingress_rules
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      security_groups  = ingress.value.security_groups
    }
  }

  # Egress rules
  dynamic "egress" {
    for_each = length(var.egress_rules) > 0 ? var.egress_rules : [
      {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        security_groups  = []
      }
    ]

    content {
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
      security_groups  = egress.value.security_groups
    }
  }

  tags = {}
}
