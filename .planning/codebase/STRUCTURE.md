# Codebase Structure

**Analysis Date:** 2026-05-20

## Directory Layout

```
dmair-terraform/
├── envs/                          # Environment root modules (independent Terraform workspaces)
│   ├── frontend/                  # Frontend (Next.js static site) environments
│   │   ├── staging/               # Staging workspace
│   │   │   ├── main.tf            # Module composition
│   │   │   ├── variables.tf       # Variable declarations
│   │   │   ├── terraform.tfvars   # Environment values (APP_NAME, domain, certs, etc.)
│   │   │   ├── backend.tf         # S3 remote state config
│   │   │   ├── providers.tf       # AWS provider version pin
│   │   │   └── output.tf          # Workspace outputs
│   │   └── prod/                  # Production workspace (same structure as staging)
│   └── strapi/                    # Strapi CMS backend workspace (single env, prod)
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── backend.tf
│       ├── providers.tf
│       ├── output.tf
│       └── startup_exact.sh       # EC2 user data script (referenced by main.tf)
├── modules/                       # Reusable child modules (no provider/backend config)
│   ├── s3/                        # S3 bucket (CORS, ACL, optional website/versioning/SSE)
│   ├── cloudfront/                # CloudFront distribution + OAC + S3 bucket policy
│   ├── cloudfront-function/       # CloudFront JS function via templatefile
│   │   ├── basic_auth.js          # Basic auth function code (staging)
│   │   └── url_rewrite.js         # URL rewrite function code (prod)
│   ├── ec2/                       # EC2 instance with AMI lookup and lifecycle guards
│   ├── ecr/                       # ECR repository with lifecycle policy
│   ├── eip/                       # Elastic IP associated to EC2 instance
│   ├── sg/                        # Security group (default or custom ingress rules)
│   ├── iam-policy/                # Renders policy templates into managed IAM policies
│   ├── iam-role/                  # IAM role with policy attachments
│   ├── iam-user/                  # IAM user with policy attachments + optional access key
│   └── secrets_manager/           # Secrets Manager secret (placeholder, no initial value)
├── policies/                      # IAM policy JSON templates (HCL templatefile format)
│   ├── s3_rw.tpl                  # S3 list + get/put/delete
│   ├── ecr_push.tpl               # ECR push (CI use)
│   ├── ecr_pull.tpl               # ECR pull (EC2 role use)
│   ├── cloudfront_invalidate.tpl  # CloudFront cache invalidation
│   ├── secrets_manager_read.tpl   # Secrets Manager read
│   ├── sg_manage.tpl              # SG ingress add/remove (GitHub Actions dynamic IP)
│   └── ses_send_mail.tpl          # SES send email (disabled/commented out in all envs)
├── .planning/                     # GSD planning documents (not Terraform)
│   └── codebase/
├── README.md
└── .gitignore
```

## Directory Purposes

**`envs/`:**
- Purpose: One subdirectory per Terraform workspace. Each is independently initialized and applied.
- Contains: `main.tf` (module calls only — no inline resources except one `aws_iam_instance_profile` and one `data` block in `envs/strapi/main.tf`), `variables.tf`, `terraform.tfvars`, `backend.tf`, `providers.tf`, `output.tf`
- Key files: `terraform.tfvars` (runtime values), `backend.tf` (state location)

**`envs/frontend/staging/`:**
- Purpose: Staging frontend infrastructure (S3 + CloudFront + basic auth + dist bucket + IAM + Secrets)
- Unique files: none beyond standard set

**`envs/frontend/prod/`:**
- Purpose: Production frontend infrastructure (S3 + CloudFront with URL rewrite + IAM + Secrets)
- Unique files: none beyond standard set

**`envs/strapi/`:**
- Purpose: Strapi CMS backend (EC2 + ECR + S3 + CloudFront + EIP + SG + IAM role/user + Secrets)
- Unique files: `startup_exact.sh` — EC2 user data shell script injected via `templatefile()` with SSH public keys

**`modules/`:**
- Purpose: Self-contained resource modules with no provider or backend configuration.
- Contains: Each module follows the standard three-file pattern: `main.tf`, `variables.tf`, `output.tf`
- Key files: `modules/iam-policy/main.tf` (policy template engine), `modules/cloudfront/main.tf` (OAC + distribution)

**`modules/cloudfront-function/`:**
- Purpose: CloudFront Function module that bundles JavaScript function code alongside Terraform
- Contains: Standard three-file module + `basic_auth.js`, `url_rewrite.js`, `README.md`
- Note: JS files are co-located in the module directory; `templatefile()` is used to inject variables (e.g., `basic_auth_credentials`) at plan time

**`policies/`:**
- Purpose: Parameterized IAM policy JSON templates. Variables use `${jsonencode(var_name)}` for safe ARN list encoding.
- Contains: `.tpl` files only — no Terraform files
- Key files: All `.tpl` files are referenced by name (without extension) in the `policy_templates` list passed to `modules/iam-policy`

## Key File Locations

**Entry Points (workspaces):**
- `envs/frontend/staging/main.tf`: Staging frontend module composition
- `envs/frontend/prod/main.tf`: Production frontend module composition
- `envs/strapi/main.tf`: Strapi backend module composition

**State Configuration:**
- `envs/frontend/staging/backend.tf`: State at `s3://dmair-terraform-prod/frontend/staging/terraform.tfstate`
- `envs/frontend/prod/backend.tf`: State at `s3://dmair-terraform-prod/frontend/prod/terraform.tfstate`
- `envs/strapi/backend.tf`: State at `s3://dmair-terraform-prod/strapi/terraform.tfstate`

**Environment Values:**
- `envs/frontend/staging/terraform.tfvars`: APP_NAME, domain (`staging.flydmair.com`), ACM cert ARN, basic auth config
- `envs/frontend/prod/terraform.tfvars`: APP_NAME, domain (`www.flydmair.com`), ACM cert ARN
- `envs/strapi/terraform.tfvars`: APP_NAME (`dmair`), ENV (`prod`), EC2 instance type/AMI, SSH public keys, CDN domain

**Provider Pin:**
- `envs/frontend/staging/providers.tf`, `envs/frontend/prod/providers.tf`, `envs/strapi/providers.tf`: All pin `hashicorp/aws = 5.91.0`

**Core Modules:**
- `modules/s3/main.tf`: S3 bucket resource definitions
- `modules/cloudfront/main.tf`: CloudFront distribution + OAC + S3 bucket policy
- `modules/iam-policy/main.tf`: Policy template rendering loop
- `modules/ec2/main.tf`: EC2 instance with lifecycle guards

**EC2 Startup Script:**
- `envs/strapi/startup_exact.sh`: User data script for EC2 initialization (injected with `jenkins_ssh_public_key` and `github_actions_ssh_public_key`)

**Policy Templates:**
- `policies/s3_rw.tpl`: S3 read/write — requires `s3_bucket_arns`
- `policies/ecr_push.tpl`: ECR push — requires `ecr_repository_arns`
- `policies/ecr_pull.tpl`: ECR pull — requires `ecr_repository_arns`
- `policies/cloudfront_invalidate.tpl`: CF invalidation — requires `cloudfront_distribution_arns`
- `policies/secrets_manager_read.tpl`: Secrets read — requires `secretsmanager_arns`
- `policies/sg_manage.tpl`: SG ingress manage — requires `security_group_arn`
- `policies/ses_send_mail.tpl`: SES send — requires `ses_resource_arns` (currently disabled in all envs)

## Naming Conventions

**Files:**
- Terraform files: `main.tf`, `variables.tf`, `output.tf`, `backend.tf`, `providers.tf` — all lowercase, no suffixes
- Policy templates: `<action>_<resource>.tpl` (snake_case) — e.g., `s3_rw.tpl`, `ecr_push.tpl`
- CloudFront function JS: `<purpose>.js` (snake_case) — e.g., `basic_auth.js`, `url_rewrite.js`

**Directories:**
- Modules: kebab-case — `cloudfront-function`, `iam-policy`, `iam-role`, `iam-user`, `secrets_manager` (exception: underscore)
- Environments: kebab-case — `frontend/staging`, `frontend/prod`

**AWS Resource Names:**
- Pattern: `lower("${APP_NAME}-${ENV}")` — all lowercase with hyphen separator
- Examples: `dmair-frontend-staging` (S3 bucket), `dmair-prod-github-actions-user` (IAM user)
- CloudFront function name: `${app_name}-${env}-${function_name}` — e.g., `dmair-frontend-staging-basic-auth`

**Terraform Variables:**
- Global/cross-cutting: `SCREAMING_SNAKE_CASE` — `APP_NAME`, `ENV`, `AWS_S3_block_public_acls`
- Module-specific: `snake_case` — `app_name`, `env`, `viewer_request_function_arn`
- Inconsistency exists: root modules use `APP_NAME`/`ENV`; child modules (cloudfront-function, eip) use `app_name`/`env`

**Outputs:**
- S3 module outputs: `S3-Bucket-NAME`, `S3-Bucket-ARN`, `S3-Bucket-Domain` (PascalCase with hyphens — matches legacy pattern)
- CloudFront module outputs: `cdn_distribution_id`, `cdn_distribution_arn`, `cdn_distribution_domain_name` (snake_case)
- IAM modules: `policy_arns_map`, `user_arn`, `user_name`, `access_key_id` (snake_case)

## Where to Add New Code

**New Environment (e.g., `envs/frontend/dev/`):**
- Copy `envs/frontend/staging/` as a starting point
- Update `terraform.tfvars` with new `APP_NAME`, `ENV`, `domain`, `acm_certificate`
- Update `backend.tf` state key to `frontend/dev/terraform.tfstate`
- Run `terraform init` from the new directory

**New Reusable Module:**
- Create `modules/<kebab-name>/main.tf`, `variables.tf`, `output.tf`
- No `backend.tf` or `providers.tf` in module directories
- If IAM policies are needed, add a `.tpl` file to `policies/` and reference it by name in `policy_templates`

**New IAM Policy Type:**
- Add `policies/<action>_<resource>.tpl` with `${jsonencode(variable_name)}` interpolation for ARN parameters
- Reference by template name (without `.tpl`) in any `module "..._policies"` block's `policy_templates` list
- Add corresponding key and value to `template_vars` map in the root module

**New CloudFront Function:**
- Add a `.js` file to `modules/cloudfront-function/` (it will be available to all env module calls)
- In the root module, add a `module "cloudfront_<name>"` block with `function_file = "<name>.js"` and appropriate `function_vars`
- Pass the resulting `function_arn` output to the `cloudfront` module's `viewer_request_function_arn`

**New Feature Flag on Existing Module:**
- Add a `bool` variable with default `false` to the module's `variables.tf`
- Gate the resource with `count = var.enable_X ? 1 : 0`
- Expose the resource's attributes conditionally in `output.tf` using `var.enable_X ? resource.attr : null`

**Utilities/Shared Scripts:**
- EC2 startup scripts: place alongside `main.tf` in the relevant `envs/<env>/` directory (e.g., `envs/strapi/startup_exact.sh`)
- Policy templates: always in `policies/` at repo root — never inline in module HCL

## Special Directories

**`.planning/`:**
- Purpose: GSD planning and codebase analysis documents
- Generated: No
- Committed: No (listed as untracked in git status)

**`.git/`:**
- Purpose: Git repository metadata
- Generated: Yes
- Committed: No

---

*Structure analysis: 2026-05-20*
