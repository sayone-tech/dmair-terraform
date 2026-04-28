output "S3-Bucket-ARN" {
  description = "S3 Bucket ARN"
  value       = module.S3_Website.S3-Bucket-ARN
}

output "S3-Bucket-NAME" {
  description = "S3 Bucket Name"
  value       = module.S3_Website.S3-Bucket-NAME
}

output "S3-Bucket-Domain" {
  description = "S3 Domain Name"
  value       = module.S3_Website.S3-Bucket-Domain
}

output "CDN-Distribution-ID" {
  description = "S3 Bucket Name"
  value       = module.cloudfront.cdn_distribution_id
}

output "CDN-Domain-Default-Name" {
  description = "Default Domain name of the cloudfront distribution"
  value       = module.cloudfront.cdn_distribution_domain_name
}

output "secretsmanager_arn" {
  value = module.secrets_manager.secretsmanager_arn
}

output "github_actions_user_arn" {
  description = "GitHub Actions IAM User ARN"
  value       = module.github_actions_user.user_arn
}

output "cloudfront_basic_auth_function_arn" {
  description = "ARN of the CloudFront basic auth function"
  value       = try(module.cloudfront_basic_auth[0].function_arn, null)
}

output "cloudfront_basic_auth_function_name" {
  description = "Name of the CloudFront basic auth function"
  value       = try(module.cloudfront_basic_auth[0].function_name, null)
}
