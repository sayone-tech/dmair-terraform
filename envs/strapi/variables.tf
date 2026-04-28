variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile"
  default     = "default"
}

variable "aws_credentials_file" {
  type        = list(string)
  default     = ["~/.aws/credentials"]
  description = "AWS credentials file in local"
}

variable "APP_NAME" {
  type        = string
  description = "Application"
}

variable "ENV" {
  type        = string
  description = "Application Env type"
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default = {
    Environment = "staging"
  }
}

# Security group configuration
variable "sg_use_default_rules" {
  type        = bool
  description = "Whether to use the default HTTP/HTTPS/SSH SG rules"
  default     = true
}

variable "sg_ingress_rules" {
  description = "Custom ingress rules for the SG when defaults are disabled"
  type = list(object({
    description      = string
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = list(string)
    ipv6_cidr_blocks = list(string)
    security_groups  = list(string)
  }))
  default = []
}

variable "sg_egress_rules" {
  description = "Custom egress rules for the SG when provided; otherwise allow all"
  type = list(object({
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = list(string)
    ipv6_cidr_blocks = list(string)
    security_groups  = list(string)
  }))
  default = []
}

variable "Github_Actions_IP" {
  type        = string
  description = "GitHub Actions Runner IP CIDR"
  default     = "34.136.212.252/32"
}

variable "Jenkins_IP" {
  type        = string
  description = "Jenkins Server IP CIDR (for SSH access)"
  default     = ""
}


# S3 module
variable "S3_cors_Allowed_Headers" {
  type    = list(string)
  default = ["*"]
}

variable "S3_cors_Allowed_Methods" {
  type    = list(string)
  default = ["GET"]
}

variable "S3_cors_Expose_Headers" {
  type    = list(string)
  default = ["ETag"]
}

variable "S3_cors_Allowed_Origins" {
  type    = list(string)
  default = ["*"]
}

variable "S3_cors_Max_Age" {
  type    = number
  default = 3000
}

variable "AWS_S3_Bucket_ACL_TYPE" {
  type    = string
  default = "private"
}

variable "AWS_S3_block_public_acls" {
  type    = bool
  default = true
}

variable "AWS_S3_block_public_policy" {
  type    = bool
  default = true
}

variable "AWS_S3_restrict_public_buckets" {
  type    = bool
  default = true
}

# CloudFront (optional)
variable "cdn_domain" {
  type        = string
  description = "Backend CDN custom domain (e.g., api.staging.example.com)"
  default     = ""
}

variable "acm_certificate" {
  type        = string
  description = "ACM certificate ARN for CloudFront (in us-east-1)"
  default     = ""
}

# EC2 instance variables (used by ec2 module)
variable "EC2_AMI_FILTER" {
  type    = string
  default = "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"
}

variable "EC2_INSTANCE_TYPE" {
  type    = string
  default = "t3.micro"
}

variable "EC2_PRIVATE_KEY" {
  type    = string
  default = ""
}

variable "EC2_AZ" {
  type    = string
  default = ""
}

variable "EC2_AMI" {
  type    = string
  default = ""
}

variable "EC2_USER_DATA" {
  type        = string
  description = "Optional path to user data script file"
  default     = ""
}

variable "EC2_USER_DATA_CONTENT" {
  type        = string
  description = "Optional rendered user data content"
  default     = ""
}

variable "EC2_ROOT_VOLUME_TYPE" {
  type    = string
  default = "gp3"
}

variable "EC2_ROOT_VOLUME_SIZE" {
  type    = number
  default = 20
}

variable "EC2_CPU_CREDITS" {
  type    = string
  default = "standard"
}

variable "jenkins_ssh_public_key" {
  type        = string
  description = "Public SSH key to inject via startup.sh"
  default     = ""
}

variable "github_actions_ssh_public_key" {
  type        = string
  description = "GitHub Actions public SSH key to inject via startup.sh"
  default     = ""
}

# SES configuration
# variable "ses_identity_arn" {
#   type        = list(string)
#   description = "List of SES identity ARNs (email or domain) for sending emails"
#   default     = []
# }

# variable "ses_from_email" {
#   type        = string
#   description = "SES verified email address to send emails from"
#   default     = ""
# }
