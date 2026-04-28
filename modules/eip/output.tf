output "eip_id" {
  description = "The allocation ID of the Elastic IP"
  value       = aws_eip.this.id
}

output "eip_public_ip" {
  description = "The public IP address of the Elastic IP"
  value       = aws_eip.this.public_ip
}

output "eip_public_dns" {
  description = "The public DNS name of the Elastic IP"
  value       = aws_eip.this.public_dns
}

output "eip_private_ip" {
  description = "The private IP address associated with the Elastic IP"
  value       = aws_eip.this.private_ip
}

output "eip_private_dns" {
  description = "The private DNS name associated with the Elastic IP"
  value       = aws_eip.this.private_dns
}

output "eip_association_id" {
  description = "The association ID of the Elastic IP"
  value       = aws_eip.this.association_id
}
