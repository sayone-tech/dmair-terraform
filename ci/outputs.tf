output "plan_readonly_role_arn" {
  description = "Assumed by terraform.yml plan job on PRs + push-to-main."
  value       = aws_iam_role.plan_readonly.arn
}

output "staging_apply_role_arn" {
  description = "Assumed by terraform.yml apply job for live/dmair/staging/* stacks (push-to-main)."
  value       = aws_iam_role.staging_apply.arn
}

output "prod_apply_role_arn" {
  description = "Assumed by terraform.yml apply job for bootstrap + live/dmair/prod/* stacks. Gated by the 'prod' GitHub Environment with required reviewers."
  value       = aws_iam_role.prod_apply.arn
}

output "github_oidc_provider_arn" {
  description = "Account-wide OIDC provider this stack references (created in Phase 3's live/dmair/staging/backend/oidc.tf)."
  value       = data.aws_iam_openid_connect_provider.github.arn
}
