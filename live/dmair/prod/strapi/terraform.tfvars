APP_NAME    = "dmair"
ENV         = "prod"
aws_region  = "us-west-2"
aws_profile = "dmair"

# CloudFront CDN Configuration (for S3 media/uploads)
cdn_domain      = "strapi-cdn.dmair.net"                                                                # Your custom CloudFront domain
acm_certificate = "arn:aws:acm:us-east-1:071297531943:certificate/88755027-a98c-4ef0-b63b-7507303d55d1" # ACM certificate ARN (must be in us-east-1)

# Tags
tags = {
  Env = "prod"
}

# S3 CORS (origins must be exact or "*")
S3_cors_Allowed_Origins = ["https://dmair.net", "https://dmair.net/*", "https://strapi-cdn.dmair.net"]

# Security Group - enable default HTTP/HTTPS and SSH (with GitHub Actions and Jenkins CIDR)
sg_use_default_rules = true
Github_Actions_IP    = "34.136.212.251/32"
Jenkins_IP           = "34.136.212.252/32" # Replace with your Jenkins server IP

EC2_ROOT_VOLUME_SIZE = 12
EC2_PRIVATE_KEY      = "dmair-strapi"
EC2_INSTANCE_TYPE    = "t3.small"
# Specify AMI directly to avoid slow AMI lookup (Ubuntu 24.04 LTS for us-west-2)
EC2_AMI                       = "ami-0786adace1541ca80"
github_actions_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKXJejv/h/rsV/UPQV8e551YegMLhRe76F9eb22FgnDW starpi@rw1.com"
# SES Configuration (commented out - to be configured later)
# ses_identity_arn = [
#   "arn:aws:ses:us-west-2:071297531943:identity/dmair.net"
# ]
# ses_from_email = "hello@dmair.net"
