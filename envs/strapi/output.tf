output "S3-Bucket-ARN" {
  description = "S3 Bucket ARN"
  value       = module.app_s3_bucket.S3-Bucket-ARN
}

output "S3-Bucket-NAME" {
  description = "S3 Bucket Name"
  value       = module.app_s3_bucket.S3-Bucket-NAME
}

output "S3-Bucket-Domain" {
  description = "S3 Domain Name"
  value       = module.app_s3_bucket.S3-Bucket-Domain
}

output "CDN-Distribution-ID" {
  description = "CloudFront Distribution ID"
  value       = module.cloudfront.cdn_distribution_id
}

output "CDN-Domain-Default-Name" {
  description = "Default Domain name of the cloudfront distribution"
  value       = module.cloudfront.cdn_distribution_domain_name
}

output "ECR-Repository-URI" {
  description = "ECR Repository URI"
  value       = module.app_ecr.repository_url
}

output "EC2-Instance-ID" {
  description = "EC2 Instance ID"
  value       = module.ec2_instance.instance_id
}

output "secretsmanager_arn" {
  description = "Secrets Manager ARN"
  value       = module.app_secrets.secretsmanager_arn
}

output "github_actions_user_arn" {
  description = "GitHub Actions IAM User ARN"
  value       = module.github_actions_user.user_arn
}

output "app_user_arn" {
  description = "Strapi App IAM User ARN (for S3 access)"
  value       = module.app_user.user_arn
}

output "app_user_name" {
  description = "Strapi App IAM User Name (for creating access keys)"
  value       = module.app_user.user_name
}

# output "ses_user_arn" {
#   description = "SES IAM User ARN (for email sending)"
#   value       = module.ses_user.user_arn
# }

# output "ses_user_name" {
#   description = "SES IAM User Name (for creating access keys)"
#   value       = module.ses_user.user_name
# }


output "ec2_role_arn" {
  description = "EC2 IAM Role ARN"
  value       = module.ec2_role.role_arn
}

output "eip_id" {
  description = "Elastic IP allocation ID"
  value       = module.backend_eip.eip_id
}

output "eip_public_ip" {
  description = "Elastic IP public address"
  value       = module.backend_eip.eip_public_ip
}

output "eip_public_dns" {
  description = "Elastic IP public DNS name"
  value       = module.backend_eip.eip_public_dns
}

output "ec2_private_ip" {
  description = "EC2 Private IP"
  value       = module.ec2_instance.private_ip
}

# output "ses_identity_arn" {
#   description = "SES Identity ARN (if configured)"
#   value       = length(var.ses_identity_arn) > 0 ? var.ses_identity_arn : ["Not configured"]
# }

# output "ses_from_email" {
#   description = "SES From Email Address (if configured)"
#   value       = var.ses_from_email != "" ? var.ses_from_email : "Not configured"
# }

# GitHub Actions IAM User Credentials (sensitive - for GitHub Secrets)
output "github_actions_access_key_id" {
  description = "GitHub Actions IAM user access key ID (add to GitHub Secrets)"
  value       = module.github_actions_user.access_key_id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "GitHub Actions IAM user secret access key (add to GitHub Secrets)"
  value       = module.github_actions_user.secret_access_key
  sensitive   = true
}

# Security Group Information (for GitHub Actions)
output "security_group_id" {
  description = "EC2 security group ID (needed for GitHub Actions to add/remove IP for SSH)"
  value       = module.sg.sg_id_ec2
}

output "security_group_arn" {
  description = "EC2 security group ARN"
  value       = module.sg.sg_arn
}

