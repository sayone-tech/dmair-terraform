output "policy_arns" {
  description = "List of managed policy ARNs created"
  value       = [for p in aws_iam_policy.this : p.arn]
}

output "policy_arns_map" {
  description = "Map of template name to managed policy ARN"
  value       = { for k, p in aws_iam_policy.this : k => p.arn }
}
