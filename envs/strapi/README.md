# Development Environment Infrastructure

Terraform configuration for the Course Equivalency Platform development environment.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Outputs](#outputs)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Terraform Documentation](#terraform-documentation)

## Overview

This Terraform configuration provisions the complete AWS infrastructure for the development environment:

- **Region:** us-west-2
- **Environment:** Development
- **Domain:** course-equivalency.dev.sayone.team
- **Managed Resources:** EC2, S3, CloudFront, ECR, Secrets Manager, IAM, Security Groups

## Architecture

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS us-west-2                         │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │  CloudFront  │────────▶│  S3 Bucket   │                 │
│  │ Distribution │         │ (Static Files)│                 │
│  └──────────────┘         └──────────────┘                 │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │  Elastic IP  │────────▶│  EC2 Instance│                 │
│  │44.235.240.19 │         │   t3.micro   │                 │
│  └──────────────┘         │ Ubuntu 24.04 │                 │
│                           └──────┬───────┘                 │
│                                  │                           │
│  ┌──────────────┐         ┌─────┴────────┐                 │
│  │     ECR      │         │   Security   │                 │
│  │  Repository  │         │    Group     │                 │
│  └──────────────┘         └──────────────┘                 │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │   Secrets    │         │  IAM Roles   │                 │
│  │   Manager    │         │  & Policies  │                 │
│  └──────────────┘         └──────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

### Resources Created

| Resource | Type | Purpose |
|----------|------|---------|
| EC2 Instance | t3.micro | Application server (Ubuntu 24.04 LTS) |
| Elastic IP | Static IP | 44.235.240.19 |
| S3 Bucket (Media) | Storage | Strapi media files with CloudFront CDN |
| S3 Bucket (Backup) | Storage | Database and media backups |
| CloudFront | CDN | Content delivery for static files |
| ECR Repository | Container Registry | Docker images |
| Secrets Manager | Secrets | Application configuration |
| Security Group | Firewall | SSH (GitHub Actions), HTTP, HTTPS |
| IAM Role (EC2) | Permissions | S3 (media + backup), ECR, CloudFront, Secrets, SES |
| IAM User (GitHub Actions) | CI/CD | Deployment automation |
| IAM User (App) | Application | S3 upload and CloudFront invalidation |
| IAM User (SES) | Email | Send emails via AWS SES |

## Prerequisites

### Required Tools

- **Terraform:** >= 1.0.0
- **AWS CLI:** Configured with credentials
- **Git:** For version control

### AWS Credentials

Configure AWS credentials with appropriate permissions:

```bash
aws configure --profile course-equivalency-dev
```

Or use environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-2"
```

### Required Permissions

The AWS user/role needs permissions for:

- EC2 (instances, security groups, elastic IPs)
- S3 (buckets, objects)
- CloudFront (distributions)
- ECR (repositories)
- Secrets Manager (secrets)
- IAM (roles, policies, users)

## Quick Start

### 1. Initialize Terraform

```bash
cd infra_code/envs/dev
terraform init
```

### 2. Review Configuration

Edit `terraform.tfvars` with your values:

```hcl
APP_NAME   = "course-equivalency"
ENV        = "dev"
aws_region = "us-west-2"

# EC2 Configuration
EC2_AMI              = "ami-00f46ccd1cbfb363e"  # Ubuntu 24.04 LTS
EC2_INSTANCE_TYPE    = "t3.micro"
EC2_PRIVATE_KEY      = "course-equivalency-dev"
EC2_ROOT_VOLUME_SIZE = 12
EC2_AZ               = "us-west-2a"

# Jenkins SSH Key
jenkins_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
```

### 3. Plan Infrastructure

```bash
terraform plan
```

Review the planned changes carefully.

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

### 5. Save Outputs

```bash
terraform output > outputs.txt
```

Important outputs:

- `eip_public_ip` - Server IP address
- `ECR-Repository-URI` - Docker registry URL
- `CDN-Distribution-ID` - CloudFront distribution ID
- `S3-Bucket-NAME` - S3 bucket name

## Configuration

### terraform.tfvars

Key configuration variables:

```hcl
# Application
APP_NAME = "course-equivalency"
ENV      = "dev"

# AWS
aws_region = "us-west-2"

# EC2
EC2_AMI              = "ami-00f46ccd1cbfb363e"
EC2_INSTANCE_TYPE    = "t3.micro"
EC2_PRIVATE_KEY      = "course-equivalency-dev"
EC2_ROOT_VOLUME_SIZE = 12
EC2_ROOT_VOLUME_TYPE = "gp3"
EC2_AZ               = "us-west-2a"

# Security
Github_Actions_IP = "34.136.212.252/32"  # GitHub Actions Runner IP

# Jenkins SSH Access
jenkins_ssh_public_key = "ssh-rsa ..."

# Tags
tags = {
  Environment = "development"
  Project     = "course-equivalency"
  ManagedBy   = "terraform"
}
```

### Security Group Rules

**Default Ingress Rules:**

- SSH (22) from Jenkins IP only
- HTTP (80) from anywhere
- HTTPS (443) from anywhere

**Egress Rules:**

- All traffic allowed (for updates, API calls, etc.)

### IAM Permissions

**EC2 Role Permissions:**

- S3: Read/Write to application bucket
- ECR: Pull Docker images
- CloudFront: Create invalidations
- Secrets Manager: Read application secrets

**Jenkins User Permissions:**

- ECR: Push/Pull images
- S3: Upload static files
- Secrets Manager: Read secrets
- EC2: Describe instances

## Deployment

### Initial Deployment

```bash
# 1. Initialize
terraform init

# 2. Validate
terraform validate

# 3. Plan
terraform plan -out=tfplan

# 4. Apply
terraform apply tfplan

# 5. Save outputs
terraform output -json > outputs.json
```

### Update Infrastructure

```bash
# 1. Make changes to .tf files or terraform.tfvars

# 2. Plan changes
terraform plan

# 3. Apply changes
terraform apply
```

### Destroy Infrastructure

⚠️ **Warning:** This will destroy all resources!

```bash
# CloudFront has prevent_destroy enabled
# You must first set prevent_destroy = false in modules/cloudfront/main.tf

terraform destroy
```

### Targeted Updates

Update specific resources:

```bash
# Update only EC2 instance
terraform apply -target=module.ec2_instance

# Update only S3 bucket
terraform apply -target=module.app_s3_bucket

# Update security group
terraform apply -target=module.sg
```

## Outputs

After successful deployment, Terraform provides these outputs:

### Primary Outputs

```bash
# View all outputs
terraform output

# View specific output
terraform output eip_public_ip
terraform output ECR-Repository-URI
```

### Key Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `eip_public_ip` | Server IP address | 44.235.240.19 |
| `eip_public_dns` | Server DNS name | ec2-44-235-240-19.us-west-2.compute.amazonaws.com |
| `EC2-Instance-ID` | EC2 instance ID | i-0123456789abcdef0 |
| `ECR-Repository-URI` | Docker registry URL | 483338549852.dkr.ecr.us-west-2.amazonaws.com/course-equivalency-dev |
| `S3-Bucket-NAME` | S3 bucket name | course-equivalency-dev |
| `CDN-Distribution-ID` | CloudFront ID | E1234567890ABC |
| `CDN-Domain-Default-Name` | CloudFront domain | d1b8m7mbtc4i9s.cloudfront.net |
| `secretsmanager_arn` | Secrets Manager ARN | arn:aws:secretsmanager:... |
| `ec2_role_arn` | EC2 IAM role ARN | arn:aws:iam::... |
| `jenkins_user_arn` | Jenkins IAM user ARN | arn:aws:iam::... |

### Using Outputs in Jenkins

Configure Jenkins with these outputs:

```bash
# Get outputs in JSON format
terraform output -json > outputs.json

# Extract specific values
export SERVER_IP=$(terraform output -raw eip_public_ip)
export ECR_URL=$(terraform output -raw ECR-Repository-URI)
export CLOUDFRONT_ID=$(terraform output -raw CDN-Distribution-ID)
```

## SES Email Configuration (Optional)

### Overview

AWS SES allows the application to send emails for user notifications, password resets, etc. It's **optional** and configured via Terraform variables.

### Enable SES

**Step 1: Verify Email Identity**

```bash
# Verify your email address
aws ses verify-email-identity \
  --email-address syllabusmatching@gmail.com \
  --region us-west-2

# Check email inbox and click verification link

# Verify status
aws ses get-identity-verification-attributes \
  --identities syllabusmatching@gmail.com \
  --region us-west-2
```

**Step 2: Configure Terraform**

Update `terraform.tfvars`:

```hcl
ses_identity_arn = "arn:aws:ses:us-west-2:483338549852:identity/syllabusmatching@gmail.com"
ses_from_email   = "syllabusmatching@gmail.com"
```

**Step 3: Apply Infrastructure**

```bash
terraform plan
terraform apply
```

**Step 4: Update Application Secrets**

```bash
# Add email config to AWS Secrets Manager
aws secretsmanager update-secret \
  --secret-id course-equivalency-dev \
  --region us-west-2 \
  --secret-string '{
    "EMAIL_BACKEND": "django.core.mail.backends.smtp.EmailBackend",
    "EMAIL_HOST": "email-smtp.us-west-2.amazonaws.com",
    "EMAIL_PORT": "587",
    "EMAIL_USE_TLS": "True",
    "DEFAULT_FROM_EMAIL": "syllabusmatching@gmail.com"
  }'
```

**Step 5: Restart Application**

```bash
ssh ubuntu@44.235.240.19
docker compose restart web
```

### SES Permissions

The EC2 role will have:

- `ses:SendEmail` - Send emails
- `ses:SendRawEmail` - Send raw emails
- `ses:GetSendQuota` - Check sending limits
- `ses:GetSendStatistics` - View sending stats

### Testing

```python
# Django shell
from django.core.mail import send_mail

send_mail(
    'Test Email',
    'This is a test email via SES.',
    'syllabusmatching@gmail.com',
    ['recipient@example.com'],
    fail_silently=False,
)
```

### SES Sandbox vs Production

**Sandbox Mode (Default):**

- ✅ Can send to verified email addresses only
- ✅ 200 emails/day limit
- ❌ Cannot send to unverified recipients
- 💡 Request production access via AWS Console

**Production Mode:**

- ✅ Send to any email address
- ✅ 50,000+ emails/day
- ✅ Requires AWS approval

### Cost

- **Free Tier:** 62,000 emails/month (from EC2)
- **After Free Tier:** $0.10 per 1,000 emails

## Maintenance

### State Management

**Backend Configuration:**
Currently using local state. For production, use remote backend:

```hcl
terraform {
  backend "s3" {
    bucket = "course-equivalency-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-west-2"
  }
}
```

### State Commands

```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show module.ec2_instance.aws_instance.this

# Remove resource from state (careful!)
terraform state rm module.ec2_instance.aws_instance.this

# Import existing resource
terraform import module.ec2_instance.aws_instance.this i-0123456789abcdef0
```

### Upgrading Resources

**Update EC2 instance type:**

```hcl
# In terraform.tfvars
EC2_INSTANCE_TYPE = "t3.small"  # Changed from t3.micro
```

**Update AMI (requires recreation):**

```hcl
# In terraform.tfvars
EC2_AMI = "ami-new-ubuntu-24-04"
```

### Cost Optimization

Current monthly costs (approximate):

- EC2 t3.micro: ~$7.50
- Elastic IP: $3.60 (if not attached)
- S3: ~$0.50 (for 10GB)
- CloudFront: ~$1.00 (for 10GB transfer)
- **Total: ~$12-15/month**

## Troubleshooting

### Common Issues

**Issue: "Error creating EC2 instance"**

```bash
# Check if AMI exists in region
aws ec2 describe-images --image-ids ami-00f46ccd1cbfb363e --region us-west-2

# Verify key pair exists
aws ec2 describe-key-pairs --key-names course-equivalency-dev --region us-west-2
```

**Issue: "Error creating S3 bucket: BucketAlreadyExists"**

```bash
# S3 bucket names are globally unique
# Change APP_NAME in terraform.tfvars or delete existing bucket
```

**Issue: "Error creating CloudFront distribution"**

```bash
# Check if S3 bucket exists first
terraform apply -target=module.app_s3_bucket
# Then apply CloudFront
terraform apply -target=module.cloudfront
```

**Issue: "Error: Instance cannot be destroyed (prevent_destroy)"**

```bash
# CloudFront has prevent_destroy enabled
# Edit modules/cloudfront/main.tf and set prevent_destroy = false
# Then run terraform destroy
```

### Validation

```bash
# Validate Terraform syntax
terraform validate

# Format Terraform files
terraform fmt -recursive

# Check for security issues (requires tfsec)
tfsec .
```

### Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Save logs to file
export TF_LOG_PATH=terraform.log
terraform apply
```

## Module Structure

```
infra_code/envs/dev/
├── main.tf              # Main configuration
├── variables.tf         # Variable definitions
├── output.tf            # Output definitions
├── terraform.tfvars     # Variable values
├── provider.tf          # Provider configuration
└── README.md           # This file

infra_code/modules/
├── ec2/                # EC2 instance module
├── s3/                 # S3 bucket module
├── cloudfront/         # CloudFront distribution module
├── ecr/                # ECR repository module
├── secrets_manager/    # Secrets Manager module
├── sg/                 # Security group module
├── iam-role/          # IAM role module
├── iam-policy/        # IAM policy module
├── iam-user/          # IAM user module
└── eip/               # Elastic IP module
```

## Best Practices

1. **Always run `terraform plan` before `apply`**
2. **Use version control for .tf files**
3. **Never commit terraform.tfvars with secrets**
4. **Use remote state for team collaboration**
5. **Tag all resources appropriately**
6. **Document all changes**
7. **Test in dev before applying to production**

## Related Documentation

- [Application Deployment Guide](../../code/.config/develop/README.md)
- [Jenkins CI/CD Guide](../../code/.config/JENKINS_DEPLOYMENT.md)
- [Quick Start Guide](../../code/.config/develop/QUICK_START.md)

## Support

For issues or questions:

- Check Terraform logs
- Review AWS Console
- Verify credentials and permissions
- Contact DevOps team

---

# Terraform Documentation

Auto-generated documentation for Terraform modules and resources.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.91.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.91.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_app_ecr"></a> [app\_ecr](#module\_app\_ecr) | ../../modules/ecr | n/a |
| <a name="module_app_role_policies"></a> [app\_role\_policies](#module\_app\_role\_policies) | ../../modules/iam-policy | n/a |
| <a name="module_app_s3_bucket"></a> [app\_s3\_bucket](#module\_app\_s3\_bucket) | ../../modules/s3 | n/a |
| <a name="module_app_secrets"></a> [app\_secrets](#module\_app\_secrets) | ../../modules/secrets_manager | n/a |
| <a name="module_app_sqs"></a> [app\_sqs](#module\_app\_sqs) | ../../modules/sqs | n/a |
| <a name="module_cloudfront"></a> [cloudfront](#module\_cloudfront) | ../../modules/cloudfront | n/a |
| <a name="module_ec2_instance"></a> [ec2\_instance](#module\_ec2\_instance) | ../../modules/ec2 | n/a |
| <a name="module_ec2_role"></a> [ec2\_role](#module\_ec2\_role) | ../../modules/iam-role | n/a |
| <a name="module_jenkins_policies"></a> [jenkins\_policies](#module\_jenkins\_policies) | ../../modules/iam-policy | n/a |
| <a name="module_jenkins_user"></a> [jenkins\_user](#module\_jenkins\_user) | ../../modules/iam-user | n/a |
| <a name="module_sg"></a> [sg](#module\_sg) | ../../modules/sg | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.ec2](https://registry.terraform.io/providers/hashicorp/aws/5.91.0/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy_document.assume_ec2](https://registry.terraform.io/providers/hashicorp/aws/5.91.0/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_APP_NAME"></a> [APP\_NAME](#input\_APP\_NAME) | Application | `string` | n/a | yes |
| <a name="input_AWS_S3_Bucket_ACL_TYPE"></a> [AWS\_S3\_Bucket\_ACL\_TYPE](#input\_AWS\_S3\_Bucket\_ACL\_TYPE) | n/a | `string` | `"private"` | no |
| <a name="input_AWS_S3_block_public_acls"></a> [AWS\_S3\_block\_public\_acls](#input\_AWS\_S3\_block\_public\_acls) | n/a | `bool` | `true` | no |
| <a name="input_AWS_S3_block_public_policy"></a> [AWS\_S3\_block\_public\_policy](#input\_AWS\_S3\_block\_public\_policy) | n/a | `bool` | `true` | no |
| <a name="input_AWS_S3_restrict_public_buckets"></a> [AWS\_S3\_restrict\_public\_buckets](#input\_AWS\_S3\_restrict\_public\_buckets) | n/a | `bool` | `true` | no |
| <a name="input_EC2_AMI"></a> [EC2\_AMI](#input\_EC2\_AMI) | n/a | `string` | `""` | no |
| <a name="input_EC2_AMI_FILTER"></a> [EC2\_AMI\_FILTER](#input\_EC2\_AMI\_FILTER) | EC2 instance variables (used by ec2 module) | `string` | `""` | no |
| <a name="input_EC2_AZ"></a> [EC2\_AZ](#input\_EC2\_AZ) | n/a | `string` | `""` | no |
| <a name="input_EC2_CPU_CREDITS"></a> [EC2\_CPU\_CREDITS](#input\_EC2\_CPU\_CREDITS) | n/a | `string` | `"standard"` | no |
| <a name="input_EC2_INSTANCE_TYPE"></a> [EC2\_INSTANCE\_TYPE](#input\_EC2\_INSTANCE\_TYPE) | n/a | `string` | `"t3.micro"` | no |
| <a name="input_EC2_PRIVATE_KEY"></a> [EC2\_PRIVATE\_KEY](#input\_EC2\_PRIVATE\_KEY) | n/a | `string` | `""` | no |
| <a name="input_EC2_ROOT_VOLUME_SIZE"></a> [EC2\_ROOT\_VOLUME\_SIZE](#input\_EC2\_ROOT\_VOLUME\_SIZE) | n/a | `number` | `20` | no |
| <a name="input_EC2_ROOT_VOLUME_TYPE"></a> [EC2\_ROOT\_VOLUME\_TYPE](#input\_EC2\_ROOT\_VOLUME\_TYPE) | n/a | `string` | `"gp3"` | no |
| <a name="input_EC2_USER_DATA"></a> [EC2\_USER\_DATA](#input\_EC2\_USER\_DATA) | Optional path to user data script file | `string` | `""` | no |
| <a name="input_EC2_USER_DATA_CONTENT"></a> [EC2\_USER\_DATA\_CONTENT](#input\_EC2\_USER\_DATA\_CONTENT) | Optional rendered user data content | `string` | `""` | no |
| <a name="input_ENV"></a> [ENV](#input\_ENV) | Application Env type | `string` | n/a | yes |
| <a name="input_S3_cors_Allowed_Headers"></a> [S3\_cors\_Allowed\_Headers](#input\_S3\_cors\_Allowed\_Headers) | S3 module | `list(string)` | <pre>[<br/>  "*"<br/>]</pre> | no |
| <a name="input_S3_cors_Allowed_Methods"></a> [S3\_cors\_Allowed\_Methods](#input\_S3\_cors\_Allowed\_Methods) | n/a | `list(string)` | <pre>[<br/>  "GET"<br/>]</pre> | no |
| <a name="input_S3_cors_Allowed_Origins"></a> [S3\_cors\_Allowed\_Origins](#input\_S3\_cors\_Allowed\_Origins) | n/a | `list(string)` | <pre>[<br/>  "*"<br/>]</pre> | no |
| <a name="input_S3_cors_Expose_Headers"></a> [S3\_cors\_Expose\_Headers](#input\_S3\_cors\_Expose\_Headers) | n/a | `list(string)` | <pre>[<br/>  "ETag"<br/>]</pre> | no |
| <a name="input_S3_cors_Max_Age"></a> [S3\_cors\_Max\_Age](#input\_S3\_cors\_Max\_Age) | n/a | `number` | `3000` | no |
| <a name="input_Github_Actions_IP"></a> [Github\_Actions\_IP](#input\_Github\_Actions\_IP) | GitHub Actions Runner IP CIDR | `string` | `"34.136.212.252/32"` | no |
| <a name="input_acm_certificate"></a> [acm\_certificate](#input\_acm\_certificate) | ACM certificate ARN for CloudFront (in us-east-1) | `string` | `""` | no |
| <a name="input_aws_credentials_file"></a> [aws\_credentials\_file](#input\_aws\_credentials\_file) | AWS credentials file in local | `list(string)` | <pre>[<br/>  "~/.aws/credentials"<br/>]</pre> | no |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile | `string` | `"default"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | n/a | yes |
| <a name="input_cdn_domain"></a> [cdn\_domain](#input\_cdn\_domain) | Backend CDN custom domain (e.g., api.staging.example.com) | `string` | `""` | no |
| <a name="input_jenkins_ssh_public_key"></a> [jenkins\_ssh\_public\_key](#input\_jenkins\_ssh\_public\_key) | Public SSH key to inject via startup.sh | `string` | `""` | no |
| <a name="input_ses_resource_arns"></a> [ses\_resource\_arns](#input\_ses\_resource\_arns) | List of SES resource ARNs (identities and configuration sets) for email sending | `list(string)` | `[]` | no |
| <a name="input_sg_egress_rules"></a> [sg\_egress\_rules](#input\_sg\_egress\_rules) | Custom egress rules for the SG when provided; otherwise allow all | <pre>list(object({<br/>    from_port        = number<br/>    to_port          = number<br/>    protocol         = string<br/>    cidr_blocks      = list(string)<br/>    ipv6_cidr_blocks = list(string)<br/>    security_groups  = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_sg_ingress_rules"></a> [sg\_ingress\_rules](#input\_sg\_ingress\_rules) | Custom ingress rules for the SG when defaults are disabled | <pre>list(object({<br/>    description      = string<br/>    from_port        = number<br/>    to_port          = number<br/>    protocol         = string<br/>    cidr_blocks      = list(string)<br/>    ipv6_cidr_blocks = list(string)<br/>    security_groups  = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_sg_use_default_rules"></a> [sg\_use\_default\_rules](#input\_sg\_use\_default\_rules) | Whether to use the default HTTP/HTTPS/SSH SG rules | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A mapping of tags to assign to the resources | `map(string)` | <pre>{<br/>  "Environment": "staging"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_CDN-Distribution-ID"></a> [CDN-Distribution-ID](#output\_CDN-Distribution-ID) | CloudFront Distribution ID |
| <a name="output_CDN-Domain-Default-Name"></a> [CDN-Domain-Default-Name](#output\_CDN-Domain-Default-Name) | Default Domain name of the cloudfront distribution |
| <a name="output_EC2-Instance-ID"></a> [EC2-Instance-ID](#output\_EC2-Instance-ID) | EC2 Instance ID |
| <a name="output_ECR-Repository-URI"></a> [ECR-Repository-URI](#output\_ECR-Repository-URI) | ECR Repository URI |
| <a name="output_S3-Bucket-ARN"></a> [S3-Bucket-ARN](#output\_S3-Bucket-ARN) | S3 Bucket ARN |
| <a name="output_S3-Bucket-Domain"></a> [S3-Bucket-Domain](#output\_S3-Bucket-Domain) | S3 Domain Name |
| <a name="output_S3-Bucket-NAME"></a> [S3-Bucket-NAME](#output\_S3-Bucket-NAME) | S3 Bucket Name |
| <a name="output_SQS-Queue-URL"></a> [SQS-Queue-URL](#output\_SQS-Queue-URL) | SQS Queue URL |
| <a name="output_backend_artifacts_bucket"></a> [backend\_artifacts\_bucket](#output\_backend\_artifacts\_bucket) | S3 Bucket Name (legacy) |
| <a name="output_backend_artifacts_bucket_arn"></a> [backend\_artifacts\_bucket\_arn](#output\_backend\_artifacts\_bucket\_arn) | S3 Bucket ARN (legacy) |
| <a name="output_cloudfront_domain"></a> [cloudfront\_domain](#output\_cloudfront\_domain) | CloudFront Domain (legacy) |
| <a name="output_ec2_public_ip"></a> [ec2\_public\_ip](#output\_ec2\_public\_ip) | EC2 Public IP (legacy) |
| <a name="output_ec2_role_arn"></a> [ec2\_role\_arn](#output\_ec2\_role\_arn) | EC2 IAM Role ARN |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | ECR Repository URL (legacy) |
| <a name="output_jenkins_iam_user_arn"></a> [jenkins\_iam\_user\_arn](#output\_jenkins\_iam\_user\_arn) | Jenkins IAM User ARN (legacy) |
| <a name="output_jenkins_user_arn"></a> [jenkins\_user\_arn](#output\_jenkins\_user\_arn) | Jenkins IAM User ARN |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | S3 Bucket Name (legacy) |
| <a name="output_secretsmanager_arn"></a> [secretsmanager\_arn](#output\_secretsmanager\_arn) | Secrets Manager ARN |
| <a name="output_sqs_queue_arn"></a> [sqs\_queue\_arn](#output\_sqs\_queue\_arn) | SQS Queue ARN (legacy) |
| <a name="output_sqs_queue_url"></a> [sqs\_queue\_url](#output\_sqs\_queue\_url) | SQS Queue URL (legacy) |
<!-- END_TF_DOCS -->