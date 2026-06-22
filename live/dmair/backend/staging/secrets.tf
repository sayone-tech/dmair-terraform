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

  # Guardrail (STATE.md 'Lessons & Guardrails' #2): this secret is rebuilt from
  # SSM on every apply, so a placeholder left in any source param silently ships
  # to the app. ssm.tf's data sources fail loud when a param is MISSING, but not
  # when it holds a PENDING_REPLACE_* sentinel (setup-oidc-roles.sh seeds
  # mail_password + the ingest pair as placeholders). Fail the plan hard if any
  # source value still looks like a placeholder — keep the failure loud.
  lifecycle {
    precondition {
      condition = alltrue([
        for v in [
          data.aws_ssm_parameter.jwt_secret_key.value,
          data.aws_ssm_parameter.db_password.value,
          data.aws_ssm_parameter.mail_password.value,
          data.aws_ssm_parameter.admin_bootstrap_password.value,
          data.aws_ssm_parameter.ingest_oauth_google_client_id.value,
          data.aws_ssm_parameter.ingest_oauth_google_client_secret.value,
        ] : !can(regex("PENDING_REPLACE", v))
      ])
      error_message = "A /dmair/staging/* SSM parameter still holds a PENDING_REPLACE_* placeholder. Rotate it to the real value (aws ssm put-parameter --overwrite ...) before applying — otherwise the placeholder is written into the dmair/staging/app secret and the app boots broken (STATE.md guardrail #2)."
    }
  }

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
