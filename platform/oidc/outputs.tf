output "github_oidc_provider_arn" {
  description = "Account-wide GitHub Actions OIDC provider ARN. Sibling stacks should `data` it, not recreate."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "plan_readonly_role_arn" {
  description = "Assumed by terraform.yml plan job on PRs + push-to-main. Set as repo secret AWS_PLAN_ROLE_ARN."
  value       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dmair-terraform-plan-readonly"
}

output "staging_apply_role_arn" {
  description = "Assumed by terraform.yml apply-staging job (workflow_dispatch). Set as repo secret AWS_STAGING_APPLY_ROLE_ARN."
  value       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dmair-terraform-staging-apply"
}

output "prod_apply_role_arn" {
  description = "Assumed by terraform.yml apply-prod job (workflow_dispatch + 'prod' GitHub Environment). Set as repo secret AWS_PROD_APPLY_ROLE_ARN."
  value       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dmair-terraform-prod-apply"
}
