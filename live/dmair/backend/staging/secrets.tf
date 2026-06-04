# Single consolidated app secret per spec §3.8.
# Stored as JSON; fetched at container start by the EC2 user-data launcher.
# Sensitive values read from SSM Parameter Store at terraform plan/apply time
# — never committed, never passed via tfvars or TF_VAR_*. See ssm.tf.

resource "aws_secretsmanager_secret" "app" {
  name        = "dmair/staging/app"
  description = "dmair-backend staging consolidated app secret (JWT, DB password, Mail password, admin bootstrap, ingest OAuth)"

  tags = {
    Name = "dmair-staging-app-secret"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    JWT_SECRET_KEY           = data.aws_ssm_parameter.jwt_secret_key.value
    DB_PASSWORD              = data.aws_ssm_parameter.db_password.value
    MAIL_PASSWORD            = data.aws_ssm_parameter.mail_password.value
    ADMIN_BOOTSTRAP_PASSWORD = data.aws_ssm_parameter.admin_bootstrap_password.value

    INGEST_OAUTH_GOOGLE_CLIENT_ID     = data.aws_ssm_parameter.ingest_oauth_google_client_id.value
    INGEST_OAUTH_GOOGLE_CLIENT_SECRET = data.aws_ssm_parameter.ingest_oauth_google_client_secret.value
    INGEST_OAUTH_GOOGLE_REDIRECT_URI  = "https://${var.staging_domain}/api/v1/admin/mailbox/oauth-callback"
  })
}
