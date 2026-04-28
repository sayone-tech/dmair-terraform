output "S3-Bucket-NAME" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.website_s3.bucket
}

output "S3-Bucket-ARN" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.website_s3.arn
}

output "S3-Bucket-Domain" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.website_s3.bucket_regional_domain_name
}

output "S3-Website-Endpoint" {
  description = "S3 website endpoint"
  value       = var.enable_website ? aws_s3_bucket_website_configuration.website_s3_website[0].website_endpoint : null
}
