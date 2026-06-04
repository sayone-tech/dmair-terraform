# SSM Parameter Store — single source of truth for the sensitive values.
#
# GUARDRAIL (STATE.md 'Lessons & Guardrails' #2): secrets.tf rebuilds the
# consolidated dmair/staging/app secret from these params on EVERY apply, so any
# hand-edit to the Secrets Manager secret is reverted. Each param below MUST hold
# the REAL value — a placeholder here silently ships to the app on the next
# apply. (2026-06-04: mail_password was left a placeholder while the real
# SendGrid key lived only in the secret; an apply clobbered it → SMTP 535.)
#
# Out-of-band setup (ops, one-time per environment):
#   aws ssm put-parameter --type SecureString --tier Standard --region us-west-2 \
#       --name /dmair/staging/db_password              --value "<gen>"
#   aws ssm put-parameter --type SecureString --tier Standard --region us-west-2 \
#       --name /dmair/staging/jwt_secret_key           --value "$(openssl rand -hex 64)"
#   aws ssm put-parameter --type SecureString --tier Standard --region us-west-2 \
#       --name /dmair/staging/mail_password            --value "<sendgrid-api-key>"
#   aws ssm put-parameter --type SecureString --tier Standard --region us-west-2 \
#       --name /dmair/staging/admin_bootstrap_password --value "<gen>"
#
# Phase 13 ingest (Google OAuth / IMAP mailbox) — values come from the Google
# Cloud OAuth client (NEVER commit secret values to terraform):
#   aws ssm put-parameter --type SecureString --tier Standard --region us-west-2 \
#       --name /dmair/staging/ingest_oauth_google_client_id     --value "<oauth-client-id>"
#   aws ssm put-parameter --type SecureString --tier Standard --region us-west-2 \
#       --name /dmair/staging/ingest_oauth_google_client_secret --value "<oauth-client-secret>"
#
# Rotation: aws ssm put-parameter --overwrite --value "<new>". Then re-apply
# this stack (or re-deploy the dmair-backend app for the secrets that flow
# through the consolidated Secrets Manager secret).
#
# Read permissions: the 3 OIDC terraform CI roles already have ssm:Get* on *
# via plan-readonly's inherited refresh statement. KMS Decrypt for the
# SecureString values is granted via kms:ViaService=ssm.us-west-2.amazonaws.com
# in the same policies (no per-key ARN; works for the AWS-managed aws/ssm key).

data "aws_ssm_parameter" "db_password" {
  name            = "/dmair/staging/db_password"
  with_decryption = true
}

data "aws_ssm_parameter" "jwt_secret_key" {
  name            = "/dmair/staging/jwt_secret_key"
  with_decryption = true
}

data "aws_ssm_parameter" "mail_password" {
  name            = "/dmair/staging/mail_password"
  with_decryption = true
}

data "aws_ssm_parameter" "admin_bootstrap_password" {
  name            = "/dmair/staging/admin_bootstrap_password"
  with_decryption = true
}

data "aws_ssm_parameter" "ingest_oauth_google_client_id" {
  name            = "/dmair/staging/ingest_oauth_google_client_id"
  with_decryption = true
}

data "aws_ssm_parameter" "ingest_oauth_google_client_secret" {
  name            = "/dmair/staging/ingest_oauth_google_client_secret"
  with_decryption = true
}
