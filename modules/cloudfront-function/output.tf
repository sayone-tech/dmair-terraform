output "function_arn" {
  description = "ARN of the CloudFront function"
  value       = aws_cloudfront_function.this.arn
}

output "function_name" {
  description = "Name of the CloudFront function"
  value       = aws_cloudfront_function.this.name
}

output "function_etag" {
  description = "ETag of the CloudFront function"
  value       = aws_cloudfront_function.this.etag
}

