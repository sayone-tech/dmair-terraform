output "elastic_ip" {
  description = "Public IP for api-staging.flydmair.com. Point your GoDaddy A record at this value."
  value       = aws_eip.app.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID for SSM Session Manager access."
  value       = aws_instance.app.id
}

output "ssm_session_command" {
  description = "Drop-in command to open an SSM Session Manager shell on the staging backend."
  value       = "aws --profile dmair ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint hostname (no port). EC2 reaches it on 5432 via the staging SGs."
  value       = aws_db_instance.postgres.address
}

output "ecr_repository_url" {
  description = "Full ECR repository URL for dmair-backend. CI tags + pushes here."
  value       = aws_ecr_repository.app.repository_url
}

output "app_secret_arn" {
  description = "ARN of the consolidated dmair/staging/app secret."
  value       = aws_secretsmanager_secret.app.arn
}

output "cloudwatch_log_group" {
  description = "Log group container logs stream into (5-day retention)."
  value       = aws_cloudwatch_log_group.staging.name
}

output "dmair_backend_staging_deploy_role_arn" {
  description = "Cross-repo contract — the dmair-backend CI assumes this role via OIDC. CHANGE WITH CARE."
  value       = module.dmair_backend_staging_deploy_role.role_arn
}

output "github_oidc_provider_arn" {
  description = "Account-wide GitHub Actions OIDC provider ARN (managed in platform/oidc/; data-sourced here)."
  value       = data.aws_iam_openid_connect_provider.github.arn
}
