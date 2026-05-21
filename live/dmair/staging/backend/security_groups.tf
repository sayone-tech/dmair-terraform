# Security groups for the dmair-backend staging stack.
# EC2 SG: 80/443 in from web_ingress_cidrs; no SSH (operator access via SSM).
# RDS SG: 5432 in from the EC2 SG only.

resource "aws_security_group" "ec2" {
  name        = "dmair-staging-ec2-sg"
  description = "Inbound web traffic for the dmair-staging EC2 backend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.web_ingress_cidrs
  }

  ingress {
    description = "HTTP (ACME challenge / redirect)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.web_ingress_cidrs
  }

  # No SSH ingress — operator access is via SSM Session Manager.

  egress {
    description = "All egress (ECR / Secrets / Logs / RDS / SendGrid / Let's Encrypt / SSM)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dmair-staging-ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "dmair-staging-rds-sg"
  description = "PostgreSQL ingress from the dmair-staging EC2 instance only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dmair-staging-rds-sg"
  }
}
