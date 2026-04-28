resource "aws_secretsmanager_secret" "secretsmanager" {
  name                    = "${var.App_Name}-${var.Env_Type}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  count         = var.secret_string != null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.secretsmanager.id
  secret_string = var.secret_string
}
