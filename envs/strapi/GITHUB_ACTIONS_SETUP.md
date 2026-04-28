# Strapi EC2 Infrastructure - GitHub Actions Setup Guide

## Overview

This guide will help you set up GitHub Actions deployment for your Strapi application on AWS EC2.

## Prerequisites

Before running `terraform apply`, ensure you have:

1. **AWS CLI configured** with the correct profile (`rw1`)
2. **SSH key pair created** in AWS EC2 (named `dmair-starpi`)
3. **GitHub repository** for your Strapi application
4. **Terraform** version >= 1.0

## Step 1: Prepare SSH Keys for GitHub Actions

Generate a new SSH key pair for GitHub Actions deployment:

```bash
# Generate SSH key pair (no passphrase for automated deployments)
ssh-keygen -t ed25519 -C "github-actions-strapi" -f ~/.ssh/github-actions-strapi -N ""

# Display public key (you'll add this to terraform.tfvars)
cat ~/.ssh/github-actions-strapi.pub

# Display private key (you'll add this to GitHub Secrets)
cat ~/.ssh/github-actions-strapi
```

## Step 2: Update terraform.tfvars

Add the GitHub Actions public SSH key to your `terraform.tfvars`:

```hcl
# Add this line to terraform.tfvars
github_actions_ssh_public_key = "ssh-ed25519 AAAA... github-actions-strapi"
```

Optionally, if you also want Jenkins/manual access, add:

```hcl
jenkins_ssh_public_key = "ssh-rsa AAAA... your-jenkins-key"
```

## Step 3: Deploy Infrastructure

```bash
cd /home/nijo/sayone/projects/runway1/runway1_code/infra_code/envs/strapi

# Initialize Terraform (if not already done)
terraform init

# Review the plan
terraform plan

# Apply the infrastructure
terraform apply
```

## Step 4: Retrieve Output Values

After `terraform apply` completes, retrieve the sensitive outputs:

```bash
# Get GitHub Actions IAM access key ID
terraform output -raw github_actions_access_key_id

# Get GitHub Actions IAM secret access key
terraform output -raw github_actions_secret_access_key

# Get EC2 public IP
terraform output -raw eip_public_ip

# Get security group ID
terraform output -raw security_group_id

# Get ECR repository URI
terraform output -raw ECR-Repository-URI

# Get Secrets Manager ARN
terraform output -raw secretsmanager_arn
```

## Step 5: Configure GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Value | Source |
|-------------|-------|--------|
| `AWS_ACCESS_KEY_ID` | Your IAM access key | `terraform output -raw github_actions_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | Your IAM secret key | `terraform output -raw github_actions_secret_access_key` |
| `AWS_REGION` | `us-west-2` | Your terraform.tfvars |
| `EC2_HOST` | EC2 public IP address | `terraform output -raw eip_public_ip` |
| `EC2_USER` | `ubuntu` | Default Ubuntu user |
| `SSH_PRIVATE_KEY` | Private SSH key | Contents of `~/.ssh/github-actions-strapi` |
| `SECURITY_GROUP_ID` | Security group ID | `terraform output -raw security_group_id` |
| `ECR_REPOSITORY` | ECR repository URI | `terraform output -raw ECR-Repository-URI` |
| `SECRETS_MANAGER_ARN` | Secrets Manager ARN | `terraform output -raw secretsmanager_arn` |

## Step 6: Configure AWS Secrets Manager

Store your Strapi application secrets in AWS Secrets Manager:

```bash
# Get the Secrets Manager name
SECRETS_NAME=$(terraform output -raw secretsmanager_name 2>/dev/null || echo "dmair-prod")

# Update secrets (replace with your actual values)
aws secretsmanager put-secret-value \
  --secret-id "$SECRETS_NAME" \
  --secret-string '{
    "APP_KEYS": "key1,key2,key3,key4",
    "API_TOKEN_SALT": "your-api-token-salt",
    "ADMIN_JWT_SECRET": "your-admin-jwt-secret",
    "TRANSFER_TOKEN_SALT": "your-transfer-token-salt",
    "JWT_SECRET": "your-jwt-secret",
    "ENCRYPTION_KEY": "your-encryption-key",
    "DATABASE_PASSWORD": "your-secure-db-password",
    "DATABASE_USERNAME": "strapi_user",
    "DATABASE_NAME": "strapi_prod",
    "DATABASE_HOST": "mysql"
  }' \
  --region us-west-2 \
  --profile rw1
```

To generate secure random values:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

## GitHub Actions Workflow Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Strapi to Production

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push Docker images
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ${{ secrets.ECR_REPOSITORY }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          # Build Strapi image
          docker build -t $ECR_REPOSITORY:$IMAGE_TAG -f Dockerfile .
          docker push $ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_REPOSITORY:latest
          docker push $ECR_REPOSITORY:latest

      - name: Get runner IP
        id: ip
        run: echo "runner_ip=$(curl -s https://api.ipify.org)" >> $GITHUB_OUTPUT

      - name: Add runner IP to security group
        run: |
          aws ec2 authorize-security-group-ingress \
            --group-id ${{ secrets.SECURITY_GROUP_ID }} \
            --protocol tcp \
            --port 22 \
            --cidr ${{ steps.ip.outputs.runner_ip }}/32 \
            --region ${{ secrets.AWS_REGION }} || echo "IP already authorized"

      - name: Deploy to EC2
        env:
          PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          HOST: ${{ secrets.EC2_HOST }}
          USER: ${{ secrets.EC2_USER }}
        run: |
          echo "$PRIVATE_KEY" > private_key.pem
          chmod 600 private_key.pem
          
          ssh -o StrictHostKeyChecking=no -i private_key.pem ${USER}@${HOST} << 'EOF'
            cd /home/ubuntu/strapi  # Adjust path as needed
            
            # Login to ECR
            aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${{ secrets.ECR_REPOSITORY }}
            
            # Pull latest images
            docker compose pull
            
            # Restart services
            docker compose up -d
            
            # Clean up old images
            docker image prune -af
          EOF
          
          rm -f private_key.pem

      - name: Remove runner IP from security group
        if: always()
        run: |
          aws ec2 revoke-security-group-ingress \
            --group-id ${{ secrets.SECURITY_GROUP_ID }} \
            --protocol tcp \
            --port 22 \
            --cidr ${{ steps.ip.outputs.runner_ip }}/32 \
            --region ${{ secrets.AWS_REGION }} || echo "IP already removed"
```

## Infrastructure Resources Created

- **EC2 Instance**: `t3.small` Ubuntu 24.04 LTS
- **Elastic IP**: Static IP for the EC2 instance
- **Security Group**: HTTP (80), HTTPS (443), SSH (22)
- **ECR Repository**: For Docker images
- **S3 Bucket**: For Strapi media uploads
- **CloudFront**: CDN for S3 bucket
- **Secrets Manager**: For application secrets
- **IAM Role**: EC2 instance role with ECR pull, S3 read/write, CloudFront invalidation
- **IAM User**: GitHub Actions user with ECR push, Secrets Manager read, CloudFront invalidation, SG management

## IAM Permissions for GitHub Actions

The GitHub Actions IAM user has the following permissions:

1. **ECR Push**: Push Docker images to ECR
2. **Secrets Manager Read**: Read application secrets
3. **CloudFront Invalidation**: Invalidate CloudFront cache
4. **Security Group Management**: Add/remove SSH ingress rules temporarily

## Next Steps

1. **Configure DNS**: Point your domain to the Elastic IP
2. **SSL Certificate**: The first deployment will generate SSL certs using Certbot 
3. **Database Backups**: Set up automated MySQL backups (consider RDS for production)
4. **Monitoring**: Configure CloudWatch alarms for EC2 metrics
5. **Frontend Setup**: Deploy frontend application (separate infrastructure if needed)

## Troubleshooting

### Can't SSH to EC2
- Ensure your IP is in the security group (GitHub Actions CIDR: `34.136.212.252/32`)
- Check the SSH key is correct
- Verify the EC2 instance is running

### Docker build fails
- Check ECR login is successful
- Verify IAM permissions for ECR push
- Check Docker daemon is running on Github runner

### Can't pull from ECR on EC2
- Verify EC2 IAM role has ECR pull permissions
- Check AWS CLI is installed on EC2
- Ensure ECR login command is correct

## SES Configuration (Future)

When you're ready to enable email sending:

1. Verify your email/domain in AWS SES
2. Get the SES identity ARN
3. Uncomment the SES configuration in `terraform.tfvars`
4. Run `terraform apply` to update the infrastructure
