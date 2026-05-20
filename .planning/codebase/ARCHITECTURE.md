<!-- refreshed: 2026-05-20 -->
# Architecture

**Analysis Date:** 2026-05-20

## System Overview

```text
┌──────────────────────────────────────────────────────────────────────┐
│                        Root Modules (env workspaces)                 │
├───────────────────────┬──────────────────┬───────────────────────────┤
│  envs/frontend/prod   │ envs/frontend/   │    envs/strapi/           │
│  `envs/frontend/prod` │ staging          │    `envs/strapi`          │
│  S3 + CloudFront      │ `envs/frontend/  │    S3+CF+EC2+ECR+IAM+EIP  │
│  + IAM + Secrets      │  staging`        │    + SG + Secrets         │
└──────────┬────────────┴────────┬─────────┴───────────────┬───────────┘
           │                     │                          │
           ▼                     ▼                          ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Child Modules  (`modules/`)                        │
│  s3  cloudfront  cloudfront-function  ec2  ecr  eip  sg              │
│  iam-policy  iam-role  iam-user  secrets_manager                     │
└──────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│        Policy Templates (`policies/*.tpl`)                            │
│  s3_rw  ecr_push  ecr_pull  cloudfront_invalidate                   │
│  secrets_manager_read  sg_manage  ses_send_mail                      │
└──────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Remote State: S3 bucket `dmair-terraform-prod` (us-west-2)          │
│  Keys: frontend/staging/  frontend/prod/  strapi/terraform.tfstate   │
└──────────────────────────────────────────────────────────────────────┘
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

**Overall:** Environment-workspace root modules composing shared child modules

**Key Characteristics:**
- Each directory under `envs/` is an independent Terraform workspace (separate state, separate `terraform init`). There is no shared root module.
- Child modules under `modules/` are purely internal — no registry or external sources. All `source` paths are relative (e.g., `../../modules/s3`).
- IAM policy content is fully decoupled from IAM attachment: the `iam-policy` module renders templates from `policies/*.tpl`; the `iam-user` and `iam-role` modules accept a `policy_arns_map` output and attach them. This three-step pipeline (template → policy → user/role) is the canonical IAM composition pattern.
- Feature flags on modules use `count = var.enable_X ? 1 : 0` (e.g., `module.cloudfront_basic_auth`, `aws_s3_bucket_versioning`, `aws_s3_bucket_website_configuration`).
- CloudFront functions are optional; they are conditionally attached via `viewer_request_function_arn = var.enable_basic_auth ? module.cloudfront_basic_auth[0].function_arn : ""`.

## Layers

**Root Modules (env workspaces):**
- Purpose: Wire modules together for a specific environment. Own all `terraform.tfvars`, `backend.tf`, `providers.tf`, `outputs.tf`.
- Location: `envs/frontend/staging/`, `envs/frontend/prod/`, `envs/strapi/`
- Contains: `main.tf` (module calls), `variables.tf` (env-level vars), `terraform.tfvars` (values), `backend.tf` (S3 state), `providers.tf` (AWS provider pin), `output.tf`
- Depends on: child modules in `modules/`
- Used by: operators running `terraform plan/apply` locally or in CI

**Child Modules:**
- Purpose: Single-concern reusable resource abstractions. No knowledge of environments.
- Location: `modules/<name>/`
- Contains: `main.tf`, `variables.tf`, `output.tf` only — no `backend.tf` or `providers.tf`
- Depends on: `policies/` templates (only `iam-policy` module), nothing else
- Used by: root modules

**Policy Templates:**
- Purpose: Parameterized IAM policy JSON, rendered via `templatefile()` using `${jsonencode(...)}` for ARN lists
- Location: `policies/*.tpl`
- Contains: JSON policy documents with HCL template interpolations
- Depends on: nothing
- Used by: `modules/iam-policy/main.tf` exclusively

## Data Flow

### Frontend Deployment Flow (staging example)

1. S3 bucket created (`modules/s3`) — outputs `S3-Bucket-ARN`, `S3-Bucket-NAME`, `S3-Bucket-Domain` (`modules/s3/output.tf`)
2. Optional CloudFront function created (`modules/cloudfront-function`) — output `function_arn` (`modules/cloudfront-function/output.tf`)
3. CloudFront distribution created (`modules/cloudfront`) — consumes S3 ARN/name/domain to set OAC policy and origin; optionally attaches function ARN at `viewer-request` event (`modules/cloudfront/main.tf:68-75`); outputs `cdn_distribution_arn`, `cdn_distribution_id`
4. Secrets Manager secret created (`modules/secrets_manager`) — outputs `secretsmanager_arn`
5. IAM policies rendered (`modules/iam-policy`) — templates `s3_rw`, `cloudfront_invalidate`, `secrets_manager_read` rendered using ARNs from steps 1, 3, 4; outputs `policy_arns_map`
6. GitHub Actions IAM user created (`modules/iam-user`) — receives `policy_arns_map`; outputs `user_arn`, `access_key_id` (sensitive)

### Backend (Strapi) Deployment Flow

1. S3 bucket (`modules/s3`) — CMS media storage
2. Secrets Manager (`modules/secrets_manager`) — app secrets
3. CloudFront (`modules/cloudfront`) — CDN in front of S3
4. ECR repository (`modules/ecr`) — Docker registry with lifecycle policy (keep 3 tagged, 1 untagged)
5. Security group (`modules/sg`) — HTTP/HTTPS/22 ingress rules; supports GitHub Actions and Jenkins IP injection
6. IAM policies (`modules/iam-policy`) — `ecr_push`, `secrets_manager_read`, `cloudfront_invalidate`, `sg_manage` for CI user; `ecr_pull`, `s3_rw`, `cloudfront_invalidate` for EC2 role
7. IAM role (`modules/iam-role`) + `aws_iam_instance_profile` (inline in root module) — attached to EC2
8. EC2 instance (`modules/ec2`) — `depends_on` ECR, Secrets, instance profile, SG; user data rendered via `templatefile("startup_exact.sh", {...})` (`envs/strapi/main.tf:232-236`)
9. Elastic IP (`modules/eip`) — `depends_on` EC2 instance; `prevent_destroy = true`

### IAM Policy Pipeline (all envs)

```hcl
# Step 1: render templates
module "github_actions_policies" {
  source           = "../../modules/iam-policy"
  policy_templates = ["s3_rw", "cloudfront_invalidate"]
  template_vars    = { s3_rw = { s3_bucket_arns = [module.S3_Website.S3-Bucket-ARN] }, ... }
}
# Step 2: attach to user
module "github_actions_user" {
  source          = "../../modules/iam-user"
  policy_arns_map = merge(module.github_actions_policies.policy_arns_map)
}
```

**State Management:**
- All three workspaces share one S3 bucket `dmair-terraform-prod` (us-west-2), differentiated by state key:
  - `frontend/staging/terraform.tfstate` (`envs/frontend/staging/backend.tf`)
  - `frontend/prod/terraform.tfstate` (`envs/frontend/prod/backend.tf`)
  - `strapi/terraform.tfstate` (`envs/strapi/backend.tf`)
- Credentials use named AWS profile `dmair` with `~/.aws/credentials` (shared credentials file)
- No state locking via DynamoDB is configured in any `backend.tf` (lock table referenced only in README)

## Key Abstractions

**S3 Module:**
- Purpose: Reusable S3 bucket with configurable public-access blocking, CORS, optional website hosting, optional versioning, optional AES256 SSE
- Feature toggles: `enable_website`, `enable_versioning`, `enable_encryption` (all bool variables, defaulting to off except encryption)
- Examples: `modules/s3/main.tf`
- Pattern: `count = var.enable_X ? 1 : 0` for optional sub-resources

**CloudFront + OAC:**
- Purpose: Private S3 origin secured by Origin Access Control (sigv4 signing). Bucket policy generated via `data.aws_iam_policy_document` scoped to the specific distribution ARN.
- Pattern: `lifecycle { prevent_destroy = true }` — distributions cannot be destroyed without manual override
- Examples: `modules/cloudfront/main.tf:1-134`

**CloudFront Function Module:**
- Purpose: Wraps a JavaScript file (in the module directory) as an `aws_cloudfront_function`, with `templatefile()` for variable injection
- Two built-in functions: `basic_auth.js` (staging auth), `url_rewrite.js` (prod URL clean-up)
- The function code lives co-located in the module directory: `modules/cloudfront-function/basic_auth.js`, `modules/cloudfront-function/url_rewrite.js`

**IAM Policy Template Engine:**
- Purpose: Decouple policy JSON from Terraform resource graph. Templates in `policies/*.tpl` use `${jsonencode(variable_name)}` for safe ARN list encoding.
- Module: `modules/iam-policy/main.tf` — iterates `var.policy_templates`, calls `templatefile()` for each, creates one `aws_iam_policy` per template via `for_each`
- Output: `policy_arns_map` — a `map(string)` of `template_name => policy_arn`, used directly by `iam-user` and `iam-role` modules

## Entry Points

**Frontend Staging:**
- Location: `envs/frontend/staging/`
- Triggers: `terraform apply` from this directory
- Responsibilities: Provisions staging S3 + CloudFront with basic auth, a secondary S3+CF pair for dist artifacts, Secrets Manager, GitHub Actions IAM user

**Frontend Production:**
- Location: `envs/frontend/prod/`
- Triggers: `terraform apply` from this directory
- Responsibilities: Provisions prod S3 + CloudFront with URL-rewrite-only function, Secrets Manager, GitHub Actions IAM user

**Strapi Backend:**
- Location: `envs/strapi/`
- Triggers: `terraform apply` from this directory
- Responsibilities: Full backend stack — S3, CloudFront, ECR, Security Group, EC2 with startup script, Elastic IP, Secrets Manager, GitHub Actions CI user, Strapi app IAM user, EC2 IAM role

## Architectural Constraints

- **Independent state:** Workspaces share no Terraform state. Cross-environment resource references (e.g., prod using staging outputs) are not possible without manual data source lookups.
- **No state locking:** DynamoDB lock table is absent from all `backend.tf` configurations. Concurrent `terraform apply` runs in the same workspace can corrupt state.
- **prevent_destroy on critical resources:** `aws_cloudfront_distribution` (`modules/cloudfront/main.tf:126`), `aws_instance` (`modules/ec2/main.tf:46`), and `aws_eip` (`modules/eip/main.tf:11`) all have `lifecycle { prevent_destroy = true }`. Destroying these requires removing the lifecycle block first.
- **EC2 lifecycle ignore_changes:** `ami`, `user_data`, `key_name`, `availability_zone`, `associate_public_ip_address` are all ignored after creation (`modules/ec2/main.tf:46-51`). AMI and user data changes must be applied via instance replacement with lifecycle block removal.
- **AWS provider version pinned:** All environments pin `hashicorp/aws` at exactly `5.91.0` (`providers.tf` in each env). Module directories carry no provider requirements.
- **ACM certificates must exist in us-east-1:** CloudFront requires ACM certs in us-east-1 regardless of deployment region (us-west-2). ACM ARNs are passed as `terraform.tfvars` values; the provider does not create them.
- **Global state:** No module-level singletons or shared mutable state.
- **Circular imports:** None detected. Dependency chain is strictly: policy templates → `iam-policy` module → `iam-user`/`iam-role` modules.

## Anti-Patterns

### Hardcoded IP in Security Group Module

**What happens:** A specific IP `115.245.232.43/32` is hardcoded in `modules/sg/main.tf:39` as a default SSH ingress rule for "local" access.
**Why it's wrong:** Module-level hardcoded IPs make the module non-reusable across teams and require a module code change (not just a `tfvars` change) to update the allowed IP.
**Do this instead:** Move the "local" SSH CIDR into a `variable "Local_IP"` alongside `Github_Actions_IP` and `Jenkins_IP`, with a default of `""` (disabled).

### README State Bucket Mismatch

**What happens:** The README.md documents state bucket names `rw1-terraform-prod` and `rw1-terraform-staging`, but all `backend.tf` files use `dmair-terraform-prod`.
**Why it's wrong:** Documentation is actively misleading — operators following the README will look for the wrong bucket when troubleshooting state.
**Do this instead:** Update `README.md` state management section to reflect the actual bucket name `dmair-terraform-prod`.

### Missing DynamoDB State Locking

**What happens:** `backend.tf` blocks omit the `dynamodb_table` parameter (`envs/*/backend.tf`).
**Why it's wrong:** Without a DynamoDB lock table, concurrent `terraform apply` runs can corrupt the state file stored in S3.
**Do this instead:** Add `dynamodb_table = "dmair-terraform-lock"` to all three `backend.tf` files and create the table.

## Error Handling

**Strategy:** Terraform-native lifecycle management

**Patterns:**
- `prevent_destroy = true` on critical resources (CloudFront, EC2, EIP) to block accidental destruction
- `ignore_changes` on EC2 `ami`, `user_data`, `key_name` to avoid drift-triggered replacements after initial provisioning
- Feature flags (`count = 0/1`) on optional sub-resources to avoid resource creation errors when features are disabled

## Cross-Cutting Concerns

**Tagging:** All modules accept a `tags = map(string)` variable propagated to every resource. Standard tag key is `Env`. Some resources (e.g., `aws_security_group` in `modules/sg/main.tf:111`) use `tags = {}` — a gap.
**Naming convention:** Resources named as `lower("${APP_NAME}-${ENV}")` throughout all modules, enforcing lowercase bucket/resource names.
**Authentication (to AWS):** Named profile `dmair` via `~/.aws/credentials`. All three workspaces use identical provider configuration.

---

*Architecture analysis: 2026-05-20*
