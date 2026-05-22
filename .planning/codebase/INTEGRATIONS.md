# External Integrations

**Analysis Date:** 2026-05-20

## AWS Services Used

This repository provisions infrastructure exclusively on AWS (`us-west-2`), using the following services:

### Compute

**EC2 (`aws_instance`):**
- Purpose: Hosts the Strapi CMS backend as a containerized workload
- Module: `modules/ec2/main.tf`
- AMI: Ubuntu 24.04 LTS (ami-0786adace1541ca80 pinned in `envs/strapi/terraform.tfvars`)
- Instance type: `t3.small` (prod), default `t3.micro`
- Bootstrap: `envs/strapi/startup_exact.sh` — installs Docker, Docker Compose, and AWS CLI v2 via EC2 user data
- Lifecycle: `prevent_destroy = true` to guard against accidental teardown

**Elastic IP (`aws_eip`):**
- Purpose: Static public IP for the Strapi EC2 instance
- Module: `modules/eip/main.tf`
- Lifecycle: `prevent_destroy = true`

### Container Registry

**ECR (`aws_ecr_repository`, `aws_ecr_lifecycle_policy`):**
- Purpose: Private Docker image registry for the Strapi application
- Module: `modules/ecr/main.tf`
- Image tag mutability: `MUTABLE`
- Scan on push: enabled
- Lifecycle policy: keeps last 3 tagged images (prefixes `web`, `nginx`); deletes all but 1 untagged image

### Object Storage

**S3 (`aws_s3_bucket` + related resources):**
- Purpose (Strapi env): Media/upload storage for the Strapi CMS — `envs/strapi/main.tf` → `modules/s3`
- Purpose (frontend envs): Static website hosting for the frontend SPA — `envs/frontend/*/main.tf` → `modules/s3`
- Module: `modules/s3/main.tf`
- Encryption: AES256 server-side encryption when `enable_encryption = true`
- Public access: fully blocked (all four `block_public_*` flags set to `true`)
- Access granted to CloudFront only via OAC (Origin Access Control)
- CORS: configured per environment in `terraform.tfvars`
- Staging frontend has a second "dist" bucket (`{APP_NAME}-dist`) for a separate distribution build

**Additional S3 bucket referenced (not managed here):**
- `arn:aws:s3:::dmair-strapi-s3-backup` — backup bucket referenced in `envs/strapi/main.tf` EC2 role S3 policy; managed outside this repo

**Terraform state bucket (external):**
- `dmair-terraform-prod` (region `us-west-2`) — stores all workspace state files; not provisioned by this repo

### CDN

**CloudFront (`aws_cloudfront_distribution`, `aws_cloudfront_origin_access_control`):**
- Purpose: CDN in front of every S3 bucket (frontend and Strapi media)
- Module: `modules/cloudfront/main.tf`
- OAC (sigv4) enforces that S3 is not directly accessible
- HTTPS enforced: `viewer_protocol_policy = "redirect-to-https"`
- Price class: `PriceClass_All` (global edge locations)
- Custom domains via `aliases`; ACM certificate required (must be in `us-east-1`)
- Lifecycle: `prevent_destroy = true`
- Domains provisioned:
  - Strapi CDN: `strapi-cdn.dmair.net`
  - Frontend staging: `staging.flydmair.com`
  - Frontend prod: `www.flydmair.com`
  - Staging dist: default CloudFront domain (no custom domain)

**CloudFront Functions (`aws_cloudfront_function`):**
- Module: `modules/cloudfront-function/main.tf`
- Runtime: `cloudfront-js-1.0`
- Two functions:
  - `basic_auth.js` — HTTP Basic Authentication gate for staging; base64 credentials injected at deploy time via `templatefile`
  - `url_rewrite.js` — SPA URL rewriting for production (appends `index.html` for clean URLs, excludes `/email-sig` and `/static` paths)
- Attached at `viewer-request` event

### Certificate Management

**ACM (AWS Certificate Manager) — external, referenced only:**
- Certificates are not provisioned by this repo; ARNs are passed in via `terraform.tfvars`
- Cert ARN used by all frontend and Strapi CloudFront distributions: `arn:aws:acm:us-east-1:071297531943:certificate/73552aef-38f3-433d-8273-d4e838bfb244` (frontend)
- Cert ARN for Strapi CDN: `arn:aws:acm:us-east-1:071297531943:certificate/88755027-a98c-4ef0-b63b-7507303d55d1`
- Must be in `us-east-1` for CloudFront

### Secrets Management

**Secrets Manager (`aws_secretsmanager_secret`):**
- Purpose: Stores Strapi application secrets (DB credentials, JWT secrets, API keys) and frontend deployment secrets
- Module: `modules/secrets_manager/main.tf`
- Recovery window: configurable (`recovery_window_in_days`), default not set to 0 (not immediate delete)
- Secret names follow pattern: `{APP_NAME}-{ENV}` (e.g., `dmair-prod`, `dmair-frontend-staging`)
- Secrets content is populated post-deploy via AWS CLI; not managed by Terraform

### IAM

**IAM Policies (`aws_iam_policy`):**
- Module: `modules/iam-policy/main.tf`
- Policy templates in `policies/` directory, rendered via `templatefile`:
  - `ecr_push.tpl` — push images to ECR (for GitHub Actions)
  - `ecr_pull.tpl` — pull images from ECR (for EC2 role)
  - `s3_rw.tpl` — read/write/delete S3 objects (for Strapi app user and EC2 role)
  - `cloudfront_invalidate.tpl` — create CloudFront cache invalidations
  - `secrets_manager_read.tpl` — read secret values from Secrets Manager
  - `sg_manage.tpl` — authorize/revoke security group ingress rules (for GitHub Actions dynamic IP)
  - `ses_send_mail.tpl` — SES send email (defined but commented out — not deployed)

**IAM Roles (`aws_iam_role`):**
- Module: `modules/iam-role/main.tf`
- EC2 instance role (`{APP_NAME}-{ENV}-ec2-role`) — allows EC2 service to assume; grants ECR pull, S3 read/write, CloudFront invalidation

**IAM Users (`aws_iam_user`, `aws_iam_access_key`):**
- Module: `modules/iam-user/main.tf`
- GitHub Actions user (`{APP_NAME}-{ENV}-github-actions-user`) — programmatic access for CI/CD; access key output as sensitive Terraform output
- Strapi App user (`{APP_NAME}-{ENV}-app-user`) — programmatic S3 access from the Strapi application itself (S3 read/write + CloudFront invalidation)

**IAM Instance Profile (`aws_iam_instance_profile`):**
- Created inline in `envs/strapi/main.tf`; attaches EC2 role to the EC2 instance

### Networking

**Security Groups (`aws_security_group`):**
- Module: `modules/sg/main.tf`
- Default rules: HTTP (80, 0.0.0.0/0), HTTPS (443, 0.0.0.0/0), SSH (22) restricted to:
  - `115.245.232.43/32` (static developer/office IP — hardcoded in `modules/sg/main.tf`)
  - GitHub Actions runner IP (passed via `var.Github_Actions_IP`)
  - Jenkins server IP (passed via `var.Jenkins_IP`, optional)
- Egress: allow all by default
- `lifecycle { ignore_changes = [ingress] }` — allows GitHub Actions to temporarily add/remove its IP without triggering drift

## CI/CD Integration

**GitHub Actions:**
- IAM user and access keys provisioned by this repo for each environment
- Workflow pattern (documented in `envs/strapi/GITHUB_ACTIONS_SETUP.md`):
  1. Configure AWS credentials using provisioned IAM access keys
  2. Login to ECR and push Docker image
  3. Dynamically add GitHub Actions runner IP to EC2 security group via `sg_manage` IAM policy
  4. SSH to EC2 and run `docker compose pull && docker compose up -d`
  5. Remove runner IP from security group after deploy
- Required GitHub Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `EC2_HOST`, `EC2_USER`, `SSH_PRIVATE_KEY`, `SECURITY_GROUP_ID`, `ECR_REPOSITORY`, `SECRETS_MANAGER_ARN`

**Jenkins:**
- SSH access to EC2 is supported via optional `Jenkins_IP` variable in `envs/strapi/variables.tf`
- Jenkins SSH public key injected into EC2 via user data (`startup_exact.sh`)

## Email (SES)

**AWS SES:**
- Risk: Fully scaffolded but disabled — `ses_send_mail.tpl` policy template exists, SES IAM user and policy modules are commented out throughout `envs/strapi/main.tf` and `variables.tf`
- SES identity ARN pattern: `arn:aws:ses:us-west-2:071297531943:identity/dmair.net`
- To enable: uncomment `ses_user_policies`, `ses_user`, and `ses_identity_arn` variable blocks in `envs/strapi/main.tf` and `variables.tf`

## Data Storage

**Databases:**
- Not provisioned by Terraform — Strapi uses MySQL running as a Docker container on the EC2 instance (referenced in `GITHUB_ACTIONS_SETUP.md` secrets example: `DATABASE_HOST: mysql`)
- No RDS resource is present; setup docs note "consider RDS for production"

**File Storage:**
- S3 via `modules/s3` (see above)

**Caching:**
- None provisioned (no ElastiCache or DAX resources)

## Monitoring & Observability

**Error Tracking:**
- Not detected — no CloudWatch alarms, SNS topics, or third-party monitoring resources

**Logs:**
- Not detected — no CloudWatch Log Groups or S3 access logging configured

## Environment Configuration

**Required variables per workspace (set in `terraform.tfvars`):**
- `APP_NAME` — application name prefix for all resource names
- `ENV` — environment tag (`prod` / `staging`)
- `aws_region` — AWS region (`us-west-2`)
- `aws_profile` — AWS credentials profile (`dmair`)
- `acm_certificate` — ACM cert ARN (must be in `us-east-1`) for custom CloudFront domains
- `domain` / `cdn_domain` — custom domain for CloudFront alias

**Strapi-specific required variables:**
- `EC2_PRIVATE_KEY` — name of EC2 key pair in AWS
- `EC2_AMI` — specific AMI ID (or leave empty to use AMI filter lookup)
- `EC2_INSTANCE_TYPE` — EC2 instance size
- `github_actions_ssh_public_key` — injected into EC2 authorized_keys via user data

**Secrets location:**
- Application secrets (Strapi runtime config): AWS Secrets Manager, populated post-deploy via AWS CLI
- Terraform IAM access keys: Terraform sensitive outputs — must be retrieved via `terraform output -raw` and stored in GitHub repository secrets

---

*Integration audit: 2026-05-20*
