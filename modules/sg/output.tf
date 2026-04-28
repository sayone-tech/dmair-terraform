output "sg_id_ec2" {
  description = "Security group ID"
  value       = aws_security_group.sg_ec2_defaults[0].id
}

output "sg_arn" {
  description = "Security group ARN"
  value       = aws_security_group.sg_ec2_defaults[0].arn
}
