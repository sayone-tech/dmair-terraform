# RDS PostgreSQL 16 + PostGIS (PostGIS extension is created at migration time
# by Flyway V6 — see spec §3.6 / §6 step 4. We do NOT manage CREATE EXTENSION
# from Terraform; the master user has the privilege and Flyway handles it.)

resource "aws_db_subnet_group" "main" {
  name        = "dmair-staging-db-subnets"
  description = "Subnet group spanning both public subnets (RDS requirement: >= 2 AZs)"
  subnet_ids  = aws_subnet.public[*].id

  tags = {
    Name = "dmair-staging-db-subnets"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "dmair-staging"
  engine                 = "postgres"
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = 100 # autoscale ceiling
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = var.db_backup_retention_days
  skip_final_snapshot     = true
  apply_immediately       = true
  deletion_protection     = false

  # The DB instance is not stateful across destroys in staging by design;
  # data lives in app fixtures + Flyway baselines. deletion_protection
  # is intentionally false here — flip to true once real test data is
  # in play.

  tags = {
    Name = "dmair-staging-rds"
  }

  lifecycle {
    # Avoid Terraform churn from automatic minor-version upgrades AWS may apply.
    ignore_changes = [engine_version]
  }
}
