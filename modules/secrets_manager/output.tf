output "secretsmanager_arn" {
  description = "Secrets Manager secret ARN"
  value       = aws_secretsmanager_secret.secretsmanager.arn
}

output "secretsmanager_name" {
  description = "Secrets Manager secret name"
  value       = aws_secretsmanager_secret.secretsmanager.name
}
