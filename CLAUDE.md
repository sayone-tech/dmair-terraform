<!-- GSD:project-start source:PROJECT.md -->
## Project

**dmair-terraform**

AWS infrastructure-as-code repo (Terraform + HCL) that owns the live deployment of the
`flydmair.com` product surface: a Strapi CMS on EC2, the marketing/SPA frontend
(`www.flydmair.com`, `flydmair.com`), and a staging frontend (`staging.flydmair.com`).
This GSD milestone takes the repo from "envs/-style scratchpad" to a project-keyed
`live/<project>/<env>/<component>` layout and adds a real state backend, so that the
sibling repo `dmair-backend` can land a staging deployment slot underneath the same
account.

**Core Value:** **Live infra is sacred.** After every change, `terraform plan` on every existing live
stack (`strapi`, `frontend/prod`, `frontend/staging`) must report **"No changes"** —
the refactor cannot perturb running production. The dmair-backend staging slot is
delivered on top of that invariant, not at the cost of it.

### Constraints

- **Tech stack:** Terraform CLI ≥ 1.10, `hashicorp/aws` provider pinned at `5.91.0`,
  HCL only — no Terraform Registry modules, all module sources are local `../../modules/...`
- **Region:** `us-west-2` for all stacks (existing + new staging). Hard constraint —
  changing regions would require destroying EC2 with `prevent_destroy = true`
- **AWS account:** single account, profile `dmair` for local; OIDC for CI
- **Live infra invariant:** zero-change plans on strapi / frontend-prod / frontend-staging
  after every Phase 9 commit. This is the gate, not the goal
- **No managed test suite** — quality comes from `terraform plan` diffs reviewed by
  humans, plus the zero-change invariant. Introducing tooling is out of scope this milestone
- **Cross-repo coordination:** `staging-api.flydmair.com` DNS + OIDC role names are
  contracts the `dmair-backend` repo will consume. Renaming them later is expensive
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- HCL (HashiCorp Configuration Language) - All Terraform infrastructure definitions across `envs/` and `modules/`
- JSON - IAM policy templates in `policies/*.tpl` (rendered via Terraform `templatefile`)
- JavaScript (CloudFront JS runtime 1.0) - CloudFront edge functions at `modules/cloudfront-function/basic_auth.js` and `modules/cloudfront-function/url_rewrite.js`
- Bash - EC2 user-data bootstrap script at `envs/strapi/startup_exact.sh`
## Runtime
- Terraform CLI >= 1.10 (Phase 1 onward — required for S3-native state locking; per-workspace pin is "~> 1.15")
- AWS Provider is the sole runtime dependency — no local compute runtime
- Terraform module system (local `source = "../../modules/..."` paths only — no Terraform Registry modules used)
- Lockfile: Present at each workspace — `envs/strapi/.terraform.lock.hcl`, `envs/frontend/staging/.terraform.lock.hcl`, `envs/frontend/prod/.terraform.lock.hcl`
## Frameworks
- Terraform — Infrastructure-as-Code provisioning for all AWS resources
- HashiCorp AWS Provider `5.91.0` (`hashicorp/aws`) — pinned identically in all three workspaces
- `templatefile()` built-in function — used to render IAM policy JSON from `.tpl` files in `policies/`
- `templatefile()` also renders the EC2 user-data script at `envs/strapi/startup_exact.sh`
- Not detected — no `terratest`, `checkov`, `tfsec`, or other IaC test tooling found
## Key Dependencies
- `hashicorp/aws` `5.91.0` — entire infrastructure depends on this single provider; pinned with hash verification in lockfiles
- No external Terraform Registry modules — all module dependencies are internal (`../../modules/`)
## Configuration
- Each workspace has a `terraform.tfvars` supplying environment-specific values (region, app name, ACM cert ARN, EC2 instance type, SSH keys, domain names)
- AWS credentials are read from local `~/.aws/credentials` using named profile `dmair` — configured via `shared_credentials_files` and `profile` in each `providers.tf`
- No `.env` files — secrets are managed in AWS Secrets Manager at runtime; IAM access keys are Terraform outputs marked `sensitive = true`
- `envs/strapi/providers.tf` — Terraform + AWS provider config for Strapi environment
- `envs/frontend/staging/providers.tf` — provider config for frontend staging
- `envs/frontend/prod/providers.tf` — provider config for frontend prod
- `policies/*.tpl` — parameterized IAM policy JSON templates consumed by `modules/iam-policy/main.tf`
## Platform Requirements
- Terraform CLI >= 1.10
- Each Terraform workspace pins `required_version = "~> 1.15"` in its `providers.tf` as of Phase 1 (workstation runs 1.15.3; >= 1.10 is the absolute floor because S3-native state locking via `use_lockfile = true` requires it).
- AWS CLI v2 (for credential management and running `terraform output`)
- AWS named profile `dmair` in `~/.aws/credentials`
- AWS region: `us-west-2` (all workspaces)
- Terraform state stored remotely in S3 bucket `dmair-terraform-prod` (region `us-west-2`)
- State keys: `strapi/terraform.tfstate`, `frontend/staging/terraform.tfstate`, `frontend/prod/terraform.tfstate`
- State locking via S3-native `use_lockfile = true` (Terraform 1.10+ feature) — a `.tflock` sentinel object is written alongside each `terraform.tfstate` during plan/apply. No DynamoDB table.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Variable Naming Patterns
- `EC2_AMI`, `EC2_INSTANCE_TYPE`, `EC2_ROOT_VOLUME_SIZE`
- `APP_NAME`, `ENV`
- `AWS_S3_block_public_acls`, `S3_cors_Allowed_Headers`
- `CDN_Default_Root`, `CDN_Describtion`
- `App_Name`, `Env_Type` (ec2, sg, secrets_manager modules)
- `Github_Actions_IP`, `Jenkins_IP` (sg module)
- `app_name`, `env`, `env_type` (cloudfront-function, eip modules)
- `role_name`, `assume_role_policy`, `policy_arns_map` (iam-role module)
- `user_name`, `create_access_key` (iam-user module)
- `repository_name`, `scan_on_push`, `image_tag_mutability` (ecr module)
## Output Naming Patterns
- `S3-Bucket-NAME`, `S3-Bucket-ARN`, `S3-Bucket-Domain`
- `CDN-Distribution-ID`, `CDN-Domain-Default-Name`
- `ECR-Repository-URI`, `EC2-Instance-ID`
- `cdn_distribution_id`, `cdn_distribution_arn`, `cdn_distribution_domain_name`
- `instance_id`, `instance_arn`, `public_ip`, `private_ip`
- `sg_id_ec2`, `sg_arn`
- `role_name`, `role_arn`, `user_name`, `user_arn`
- `function_arn`, `function_name`, `function_etag`
## Resource Labeling Conventions
- `aws_ecr_repository.this`, `aws_iam_role.this`, `aws_iam_policy.this`
- `aws_iam_user.this`, `aws_eip.this`, `aws_cloudfront_function.this`
- `aws_secretsmanager_secret.secretsmanager` (exception: uses logical name)
- `aws_instance.app_server` (ec2 module)
- `aws_s3_bucket.website_s3` (s3 module)
- `aws_security_group.sg_ec2_defaults` (sg module)
- `aws_cloudfront_distribution.cdn_distribution` (cloudfront module)
- `aws_iam_role_policy_attachment.attach_managed`
- `aws_iam_user_policy_attachment.attach_managed`
## Module Source Paths
## Module Call Naming
## Tagging Strategy
- `modules/sg/main.tf`: hardcodes `tags = {}` (empty, not using `var.tags`) — security group receives no tags
- `modules/ec2/main.tf`: sets only `Name = "${var.App_Name}-${var.Env_Type}"` inline, ignores a `var.tags` passthrough
- `modules/eip/main.tf`: merges caller tags with a computed `Name` tag:
## Variable Defaults and Optionality
## Conditional Resource Creation
## Lifecycle Blocks
- `modules/ec2/main.tf`: `aws_instance.app_server`
- `modules/cloudfront/main.tf`: `aws_cloudfront_distribution.cdn_distribution`
- `modules/eip/main.tf`: `aws_eip.this`
- `modules/ec2/main.tf`: ignores `user_data`, `associate_public_ip_address`, `availability_zone`, `ami`, `key_name` (allows post-deploy EC2 changes without drift)
- `modules/sg/main.tf`: ignores `ingress` (allows GitHub Actions to add/remove IPs without triggering drift)
## Resource Naming in AWS
## Policy Template Pattern
- `s3_rw.tpl` — S3 ListBucket + GetObject/PutObject/DeleteObject
- `ecr_push.tpl` — ECR authentication + push operations
- `ecr_pull.tpl` — ECR authentication + pull operations
- `cloudfront_invalidate.tpl` — CloudFront invalidation
- `secrets_manager_read.tpl` — Secrets Manager GetSecretValue + DescribeSecret
- `sg_manage.tpl` — EC2 security group ingress add/revoke
- `ses_send_mail.tpl` — SES SendEmail + SendRawEmail
## Variable Descriptions
- `envs/strapi/variables.tf`: 20 descriptions out of 37 variables (~54% coverage)
- Variables for S3 CORS config in strapi env omit `description` entirely
## Variable Validation
## Sensitive Variables and Outputs
- `modules/secrets_manager/variables.tf`: `secret_string` marked `sensitive = true`
- `modules/iam-user/output.tf`: `access_key_id` and `secret_access_key` marked `sensitive = true`
- `envs/frontend/staging/variables.tf` and `envs/frontend/prod/variables.tf`: `basic_auth_credentials` marked `sensitive = true`
- `envs/strapi/output.tf`: `github_actions_access_key_id` and `github_actions_secret_access_key` marked `sensitive = true`
## Data Sources
- `data.aws_ami.this` — AMI lookup (ec2 module)
- `data.aws_availability_zones.available` — AZ lookup (ec2 module)
- `data.aws_iam_policy_document.s3-policy` — hyphenated, exception (cloudfront module)
- `data.aws_iam_policy_document.assume_ec2` — snake_case (strapi env)
## Comments
## HCL Formatting
- Two-space indentation
- Argument assignment alignment within blocks (values aligned to column)
- Single blank lines between resource blocks
- No trailing whitespace
## Terraform Provider Version Pinning
## State Backend Pattern
## Locals Usage
- `modules/iam-policy/main.tf`: `locals { templates = {...} }` to build the template map before `for_each`
- `envs/strapi/main.tf`: `locals { startup_user_data = templatefile(...) }` to render the EC2 user-data script before passing to the module
## For Expressions
## `count = 1` Anti-Pattern
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
```text
```
## Component Responsibilities
| Component | Responsibility | Path |
|-----------|----------------|------|
| `envs/frontend/staging` | Staging frontend root module | `envs/frontend/staging/` |
| `envs/frontend/prod` | Production frontend root module | `envs/frontend/prod/` |
| `envs/strapi` | Strapi CMS backend root module | `envs/strapi/` |
| `modules/s3` | S3 bucket with CORS, ACL, optional website/versioning/encryption | `modules/s3/` |
| `modules/cloudfront` | CloudFront distribution backed by OAC S3 origin | `modules/cloudfront/` |
| `modules/cloudfront-function` | CloudFront viewer-request function (JS) via templatefile | `modules/cloudfront-function/` |
| `modules/ec2` | EC2 instance with AMI lookup, SG, IAM profile, user data | `modules/ec2/` |
| `modules/ecr` | ECR repository with lifecycle policy | `modules/ecr/` |
| `modules/eip` | Elastic IP bound to an EC2 instance | `modules/eip/` |
| `modules/sg` | Security group with default/custom ingress rules | `modules/sg/` |
| `modules/iam-policy` | Renders `.tpl` policy templates into managed IAM policies | `modules/iam-policy/` |
| `modules/iam-role` | IAM role with attached managed policies | `modules/iam-role/` |
| `modules/iam-user` | IAM user with policy attachments and optional access key | `modules/iam-user/` |
| `modules/secrets_manager` | AWS Secrets Manager secret placeholder | `modules/secrets_manager/` |
| `policies/` | JSON IAM policy templates with `${jsonencode(...)}` interpolation | `policies/` |
## Pattern Overview
- Each directory under `envs/` is an independent Terraform workspace (separate state, separate `terraform init`). There is no shared root module.
- Child modules under `modules/` are purely internal — no registry or external sources. All `source` paths are relative (e.g., `../../modules/s3`).
- IAM policy content is fully decoupled from IAM attachment: the `iam-policy` module renders templates from `policies/*.tpl`; the `iam-user` and `iam-role` modules accept a `policy_arns_map` output and attach them. This three-step pipeline (template → policy → user/role) is the canonical IAM composition pattern.
- Feature flags on modules use `count = var.enable_X ? 1 : 0` (e.g., `module.cloudfront_basic_auth`, `aws_s3_bucket_versioning`, `aws_s3_bucket_website_configuration`).
- CloudFront functions are optional; they are conditionally attached via `viewer_request_function_arn = var.enable_basic_auth ? module.cloudfront_basic_auth[0].function_arn : ""`.
## Layers
- Purpose: Wire modules together for a specific environment. Own all `terraform.tfvars`, `backend.tf`, `providers.tf`, `outputs.tf`.
- Location: `envs/frontend/staging/`, `envs/frontend/prod/`, `envs/strapi/`
- Contains: `main.tf` (module calls), `variables.tf` (env-level vars), `terraform.tfvars` (values), `backend.tf` (S3 state), `providers.tf` (AWS provider pin), `output.tf`
- Depends on: child modules in `modules/`
- Used by: operators running `terraform plan/apply` locally or in CI
- Purpose: Single-concern reusable resource abstractions. No knowledge of environments.
- Location: `modules/<name>/`
- Contains: `main.tf`, `variables.tf`, `output.tf` only — no `backend.tf` or `providers.tf`
- Depends on: `policies/` templates (only `iam-policy` module), nothing else
- Used by: root modules
- Purpose: Parameterized IAM policy JSON, rendered via `templatefile()` using `${jsonencode(...)}` for ARN lists
- Location: `policies/*.tpl`
- Contains: JSON policy documents with HCL template interpolations
- Depends on: nothing
- Used by: `modules/iam-policy/main.tf` exclusively
## Data Flow
### Frontend Deployment Flow (staging example)
### Backend (Strapi) Deployment Flow
### IAM Policy Pipeline (all envs)
```hcl
```
- All three workspaces share one S3 bucket `dmair-terraform-prod` (us-west-2), differentiated by state key:
- Credentials use named AWS profile `dmair` with `~/.aws/credentials` (shared credentials file)
- S3 backend with S3-native state locking (`use_lockfile = true`, Terraform 1.10+). The `.tflock` sentinel object lives alongside the state object in the same bucket prefix.
## Key Abstractions
- Purpose: Reusable S3 bucket with configurable public-access blocking, CORS, optional website hosting, optional versioning, optional AES256 SSE
- Feature toggles: `enable_website`, `enable_versioning`, `enable_encryption` (all bool variables, defaulting to off except encryption)
- Examples: `modules/s3/main.tf`
- Pattern: `count = var.enable_X ? 1 : 0` for optional sub-resources
- Purpose: Private S3 origin secured by Origin Access Control (sigv4 signing). Bucket policy generated via `data.aws_iam_policy_document` scoped to the specific distribution ARN.
- Pattern: `lifecycle { prevent_destroy = true }` — distributions cannot be destroyed without manual override
- Examples: `modules/cloudfront/main.tf:1-134`
- Purpose: Wraps a JavaScript file (in the module directory) as an `aws_cloudfront_function`, with `templatefile()` for variable injection
- Two built-in functions: `basic_auth.js` (staging auth), `url_rewrite.js` (prod URL clean-up)
- The function code lives co-located in the module directory: `modules/cloudfront-function/basic_auth.js`, `modules/cloudfront-function/url_rewrite.js`
- Purpose: Decouple policy JSON from Terraform resource graph. Templates in `policies/*.tpl` use `${jsonencode(variable_name)}` for safe ARN list encoding.
- Module: `modules/iam-policy/main.tf` — iterates `var.policy_templates`, calls `templatefile()` for each, creates one `aws_iam_policy` per template via `for_each`
- Output: `policy_arns_map` — a `map(string)` of `template_name => policy_arn`, used directly by `iam-user` and `iam-role` modules
## Entry Points
- Location: `envs/frontend/staging/`
- Triggers: `terraform apply` from this directory
- Responsibilities: Provisions staging S3 + CloudFront with basic auth, a secondary S3+CF pair for dist artifacts, Secrets Manager, GitHub Actions IAM user
- Location: `envs/frontend/prod/`
- Triggers: `terraform apply` from this directory
- Responsibilities: Provisions prod S3 + CloudFront with URL-rewrite-only function, Secrets Manager, GitHub Actions IAM user
- Location: `envs/strapi/`
- Triggers: `terraform apply` from this directory
- Responsibilities: Full backend stack — S3, CloudFront, ECR, Security Group, EC2 with startup script, Elastic IP, Secrets Manager, GitHub Actions CI user, Strapi app IAM user, EC2 IAM role
## Architectural Constraints
- **Independent state:** Workspaces share no Terraform state. Cross-environment resource references (e.g., prod using staging outputs) are not possible without manual data source lookups.
- **State locking via S3-native `use_lockfile = true`:** every `backend.tf` enables S3-native locking as of Phase 1. The `.tflock` sentinel object is written by Terraform to the same S3 prefix as `terraform.tfstate` during plan/apply. No DynamoDB lock table — the previously-considered approach was superseded the same afternoon (2026-05-20) it was scoped.
- **prevent_destroy on critical resources:** `aws_cloudfront_distribution` (`modules/cloudfront/main.tf:126`), `aws_instance` (`modules/ec2/main.tf:46`), and `aws_eip` (`modules/eip/main.tf:11`) all have `lifecycle { prevent_destroy = true }`. Destroying these requires removing the lifecycle block first.
- **EC2 lifecycle ignore_changes:** `ami`, `user_data`, `key_name`, `availability_zone`, `associate_public_ip_address` are all ignored after creation (`modules/ec2/main.tf:46-51`). AMI and user data changes must be applied via instance replacement with lifecycle block removal.
- **AWS provider version pinned:** All environments pin `hashicorp/aws` at exactly `5.91.0` (`providers.tf` in each env). Module directories carry no provider requirements.
- **ACM certificates must exist in us-east-1:** CloudFront requires ACM certs in us-east-1 regardless of deployment region (us-west-2). ACM ARNs are passed as `terraform.tfvars` values; the provider does not create them.
- **Global state:** No module-level singletons or shared mutable state.
- **Circular imports:** None detected. Dependency chain is strictly: policy templates → `iam-policy` module → `iam-user`/`iam-role` modules.
## Anti-Patterns
### Hardcoded IP in Security Group Module
### README State Bucket Mismatch
### Missing State Locking [RESOLVED in Phase 1]
Phase 1 (Bootstrap State Backend) enables S3-native state locking (`use_lockfile = true`) on every backend, including the new `bootstrap/` stack. The legacy DynamoDB-table approach was scoped on 2026-05-20 morning and replaced by `use_lockfile` the same afternoon.
## Error Handling
- `prevent_destroy = true` on critical resources (CloudFront, EC2, EIP) to block accidental destruction
- `ignore_changes` on EC2 `ami`, `user_data`, `key_name` to avoid drift-triggered replacements after initial provisioning
- Feature flags (`count = 0/1`) on optional sub-resources to avoid resource creation errors when features are disabled
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
