# Technology Stack

**Analysis Date:** 2026-05-20

## Languages

**Primary:**
- HCL (HashiCorp Configuration Language) - All Terraform infrastructure definitions across `envs/` and `modules/`
- JSON - IAM policy templates in `policies/*.tpl` (rendered via Terraform `templatefile`)

**Secondary:**
- JavaScript (CloudFront JS runtime 1.0) - CloudFront edge functions at `modules/cloudfront-function/basic_auth.js` and `modules/cloudfront-function/url_rewrite.js`
- Bash - EC2 user-data bootstrap script at `envs/strapi/startup_exact.sh`

## Runtime

**Environment:**
- Terraform CLI >= 1.0 (referenced in setup docs; lockfile is present per-workspace)
- AWS Provider is the sole runtime dependency — no local compute runtime

**Package Manager:**
- Terraform module system (local `source = "../../modules/..."` paths only — no Terraform Registry modules used)
- Lockfile: Present at each workspace — `envs/strapi/.terraform.lock.hcl`, `envs/frontend/staging/.terraform.lock.hcl`, `envs/frontend/prod/.terraform.lock.hcl`

## Frameworks

**Core:**
- Terraform — Infrastructure-as-Code provisioning for all AWS resources
- HashiCorp AWS Provider `5.91.0` (`hashicorp/aws`) — pinned identically in all three workspaces

**Build/Dev:**
- `templatefile()` built-in function — used to render IAM policy JSON from `.tpl` files in `policies/`
- `templatefile()` also renders the EC2 user-data script at `envs/strapi/startup_exact.sh`

**Testing:**
- Not detected — no `terratest`, `checkov`, `tfsec`, or other IaC test tooling found

## Key Dependencies

**Critical:**
- `hashicorp/aws` `5.91.0` — entire infrastructure depends on this single provider; pinned with hash verification in lockfiles

**Infrastructure:**
- No external Terraform Registry modules — all module dependencies are internal (`../../modules/`)

## Configuration

**Environment:**
- Each workspace has a `terraform.tfvars` supplying environment-specific values (region, app name, ACM cert ARN, EC2 instance type, SSH keys, domain names)
- AWS credentials are read from local `~/.aws/credentials` using named profile `dmair` — configured via `shared_credentials_files` and `profile` in each `providers.tf`
- No `.env` files — secrets are managed in AWS Secrets Manager at runtime; IAM access keys are Terraform outputs marked `sensitive = true`

**Build:**
- `envs/strapi/providers.tf` — Terraform + AWS provider config for Strapi environment
- `envs/frontend/staging/providers.tf` — provider config for frontend staging
- `envs/frontend/prod/providers.tf` — provider config for frontend prod
- `policies/*.tpl` — parameterized IAM policy JSON templates consumed by `modules/iam-policy/main.tf`

## Platform Requirements

**Development:**
- Terraform CLI >= 1.0
- AWS CLI v2 (for credential management and running `terraform output`)
- AWS named profile `dmair` in `~/.aws/credentials`
- AWS region: `us-west-2` (all workspaces)

**Production:**
- Terraform state stored remotely in S3 bucket `dmair-terraform-prod` (region `us-west-2`)
- State keys: `strapi/terraform.tfstate`, `frontend/staging/terraform.tfstate`, `frontend/prod/terraform.tfstate`
- No state locking (DynamoDB) configured — S3 backend only

---

*Stack analysis: 2026-05-20*
