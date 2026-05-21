# Single consolidated app secret per spec §3.8.
# Stored as JSON; fetched at container start by the EC2 user-data launcher.
# The four sensitive variables come from TF_VAR_* in CI — never committed.

resource "aws_secretsmanager_secret" "app" {
  name        = "dmair/staging/app"
  description = "dmair-backend staging consolidated app secret (JWT, DB password, Mail password, admin bootstrap)"

  tags = {
    Name = "dmair-staging-app-secret"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    JWT_SECRET_KEY           = var.jwt_secret_key
    DB_PASSWORD              = var.db_password
    MAIL_PASSWORD            = var.mail_password
    ADMIN_BOOTSTRAP_PASSWORD = var.admin_bootstrap_password
  })
}
