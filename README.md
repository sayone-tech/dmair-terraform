# Infrastructure as Code - Runway One Aviation

Terraform configurations for provisioning and managing AWS infrastructure for Runway One Aviation platform.

## 📋 Overview

This repository contains Infrastructure as Code (IaC) for deploying the Runway One Aviation platform across multiple environments, including:

- **Strapi CMS** - Headless CMS backend on EC2
- **Frontend** - Next.js static site on S3 + CloudFront
- **Supporting Services** - S3, Secrets Manager, IAM, ECR, CloudFront Functions

## 🏗️ Directory Structure

```
infra_code/
├── envs/                        # Environment-specific configurations
│   ├── strapi/                  # Strapi backend (production)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── README.md
│   │
│   └── frontend/                # Next.js frontend
│       ├── staging/             # Staging environment
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── terraform.tfvars
│       │
│       └── prod/                # Production environment
│           ├── main.tf
│           ├── variables.tf
│           └── terraform.tfvars
│
└── modules/                     # Reusable Terraform modules
    ├── cloudfront/              # CloudFront distributions
    ├── cloudfront-function/     # CloudFront Functions (auth, URL rewrite)
    ├── ec2/                     # EC2 instances
    ├── ecr/                     # ECR repositories
    ├── eip/                     # Elastic IPs
    ├── iam-policy/              # IAM policies (template-based)
    ├── iam-role/                # IAM roles
    ├── iam-user/                # IAM users
    ├── s3/                      # S3 buckets
    ├── secrets_manager/         # AWS Secrets Manager
    └── sg/                      # Security groups
```

## 🚀 Environments

### Strapi Backend (Production)

**Purpose:** Headless CMS backend  
**Region:** us-west-2  
**Domains:**
- CMS: `cms.dmair.net`
- CDN: `strapi-cdn.dmair.net`

**Infrastructure:**
- EC2: t3.small (Ubuntu 22.04) with Elastic IP
- S3: Media storage with CloudFront CDN
- ECR: Docker image registry
- RDS/MySQL: Dockerized on EC2
- Secrets Manager: Application secrets
- Security Groups: HTTP/HTTPS/SSH access

**Documentation:** [envs/strapi/README.md](envs/strapi/README.md)

### Frontend Staging

**Purpose:** Pre-production testing  
**Region:** us-west-2  
**Domain:** `staging.dmair.net`

**Infrastructure:**
- S3: Static site hosting
- CloudFront: CDN with basic auth + URL rewriting
- Secrets Manager: Environment variables
- IAM: GitHub Actions deployment user

**Features:**
- Basic authentication (dev access only)
- Clean URL rewriting (`/about` → `/about/index.html`)
- Excludes `/email-sig` and `/static` paths

### Frontend Production

**Purpose:** Production website  
**Region:** us-west-2  
**Domains:** `www.dmair.net`, `dmair.net`

**Infrastructure:**
- S3: Static site hosting
- CloudFront: CDN with URL rewriting (no auth)
- Secrets Manager: Environment variables
- IAM: GitHub Actions deployment user

**Features:**
- No authentication (public access)
- Clean URL rewriting
- SSL/TLS with ACM certificate

## 📦 Modules

### CloudFront Function Module

**Location:** `modules/cloudfront-function/`

**Functions:**
- `basic_auth.js` - Basic authentication + URL rewriting (staging)
- `url_rewrite.js` - Clean URL rewriting (production)

**Features:**
- Template variable substitution
- Viewer request processing
- Excludes `/email-sig` and `/static` paths from rewriting

### IAM Policy Module

**Location:** `modules/iam-policy/`

**Templates:**
- `s3_rw` - S3 read/write access
- `cloudfront_invalidate` - CloudFront cache invalidation
- `secrets_manager_read` - Secrets Manager read access
- `ecr_push_pull` - ECR image push/pull
- `ec2_role` - EC2 instance role policies

### EC2 Module

**Location:** `modules/ec2/`

**Features:**
- Prevent destroy protection (enabled by default)
- User data support
- EBS encryption
- IAM instance profile
- Security group attachment

## 🔧 Quick Start

### Prerequisites

```bash
# Install Terraform
brew install terraform  # macOS
# or download from terraform.io

# Configure AWS credentials
aws configure --profile rw1

# Verify
terraform version
aws sts get-caller-identity --profile rw1
```

### Deploy Strapi Backend

```bash
cd infra_code/envs/strapi

# Initialize
terraform init

# Review plan
terraform plan

# Apply
terraform apply

# Get outputs
terraform output
```

### Deploy Frontend Staging

```bash
cd infra_code/envs/frontend/staging

terraform init
terraform plan
terraform apply
```

### Deploy Frontend Production

```bash
cd infra_code/envs/frontend/prod

terraform init
terraform plan
terraform apply
```

## 🔐 State Management

All environments use S3 backend for state storage:

**Strapi:**
- Bucket: `rw1-terraform-prod`
- Key: `strapi/terraform.tfstate`

**Frontend Staging:**
- Bucket: `rw1-terraform-staging`
- Key: `cms/frontend/staging/terraform.tfstate`

**Frontend Production:**
- Bucket: `rw1-terraform-prod`
- Key: `cms/frontend/prod/terraform.tfstate`

## 🏷️ Resource Tagging

Standard tags applied to all resources:

```hcl
tags = {
  App         = "dmair"
  Environment = "prod"  # or "staging"
  ManagedBy   = "terraform"
}
```

## 🔒 Security

- ✅ S3 buckets: Public access blocked
- ✅ CloudFront: HTTPS only, SSL/TLS certificates
- ✅ EC2: Security groups with minimal access
- ✅ Secrets: AWS Secrets Manager
- ✅ IAM: Least privilege policies
- ✅ EBS: Encryption at rest enabled

## 💰 Cost Estimates

### Strapi (Production)
- EC2 t3.small: ~$15/month
- Elastic IP: ~$3.60/month
- S3 + CloudFront: ~$2-5/month
- **Total:** ~$20-25/month

### Frontend (Per Environment)
- S3: ~$0.50/month
- CloudFront: ~$1-3/month
- Secrets Manager: ~$0.40/month
- **Total:** ~$2-4/month

## 📚 Documentation

- [Strapi Environment](envs/strapi/README.md)
- [GitHub Actions Setup](envs/strapi/GITHUB_ACTIONS_SETUP.md)
- [Environment Variables Guide](envs/strapi/ENV_VARS_GUIDE.md)
- [Frontend Workflows](../frontend/.github/README.md)

## 🛠️ Common Tasks

### Update Infrastructure

```bash
cd infra_code/envs/<environment>
git pull
terraform plan
terraform apply
```

### Add New Environment

```bash
# Copy existing environment
cp -r envs/frontend/staging envs/frontend/new-env

# Update configuration
cd envs/frontend/new-env
vim terraform.tfvars

# Deploy
terraform init
terraform apply
```

### Rotate Secrets

```bash
# Update in AWS Secrets Manager console
# Or via CLI
aws secretsmanager update-secret \
  --secret-id dmair-prod \
  --secret-string file://secrets.json
```

### Destroy Resources

```bash
cd infra_code/envs/<environment>

# Preview destruction
terraform plan -destroy

# Destroy (CAREFUL!)
terraform destroy
```

**Note:** EC2 instances have `prevent_destroy = true` and must be manually removed from state or the lifecycle block updated before destruction.

## 🆘 Troubleshooting

### State Lock Issues

```bash
# List locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use cautiously)
terraform force-unlock <lock-id>
```

### Module Path Issues

Ensure you're using relative paths from environment directory:
```hcl
source = "../../../modules/ec2"  # ✓ Correct
source = "../../modules/ec2"      # ✗ Wrong depth
```

### CloudFront CNAME Conflicts

Ensure domain is not already assigned to another distribution:
```bash
aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[?contains(@, 'example.com')]].Id"
```

---

**Infrastructure Owner:** DevOps Team  
**Last Updated:** 2025-12-22  
**Terraform Version:** >= 1.0  
**AWS Provider:** 5.91.0
