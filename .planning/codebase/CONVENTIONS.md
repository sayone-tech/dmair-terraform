# Coding Conventions

**Analysis Date:** 2026-05-20

## Variable Naming Patterns

Variable naming is **inconsistent across modules** — three distinct styles coexist:

**SCREAMING_SNAKE_CASE** — used for AWS service-prefixed and configuration variables:
- `EC2_AMI`, `EC2_INSTANCE_TYPE`, `EC2_ROOT_VOLUME_SIZE`
- `APP_NAME`, `ENV`
- `AWS_S3_block_public_acls`, `S3_cors_Allowed_Headers`
- `CDN_Default_Root`, `CDN_Describtion`

**Mixed_Case (Title_Snake)** — used for legacy module identity variables:
- `App_Name`, `Env_Type` (ec2, sg, secrets_manager modules)
- `Github_Actions_IP`, `Jenkins_IP` (sg module)

**lowercase_snake_case** — used in newer modules and env-level variables:
- `app_name`, `env`, `env_type` (cloudfront-function, eip modules)
- `role_name`, `assume_role_policy`, `policy_arns_map` (iam-role module)
- `user_name`, `create_access_key` (iam-user module)
- `repository_name`, `scan_on_push`, `image_tag_mutability` (ecr module)

**Rule of thumb for new modules:** Use lowercase_snake_case. The SCREAMING_SNAKE_CASE style appears in modules that directly mirror `terraform.tfvars` key names from the env layer.

## Output Naming Patterns

Outputs also show two distinct styles:

**Hyphenated UPPER-Kebab** — used by the s3 module and env-level outputs:
- `S3-Bucket-NAME`, `S3-Bucket-ARN`, `S3-Bucket-Domain`
- `CDN-Distribution-ID`, `CDN-Domain-Default-Name`
- `ECR-Repository-URI`, `EC2-Instance-ID`

**lowercase_snake_case** — used by most other modules:
- `cdn_distribution_id`, `cdn_distribution_arn`, `cdn_distribution_domain_name`
- `instance_id`, `instance_arn`, `public_ip`, `private_ip`
- `sg_id_ec2`, `sg_arn`
- `role_name`, `role_arn`, `user_name`, `user_arn`
- `function_arn`, `function_name`, `function_etag`

The hyphenated style in s3 outputs (`S3-Bucket-NAME`) is consumed in env main.tf files via `module.S3_Website.S3-Bucket-ARN`. **New modules should use lowercase_snake_case for outputs.**

## Resource Labeling Conventions

Resource labels within modules follow this pattern:

**`this`** — used when a module manages a single instance of a resource type:
- `aws_ecr_repository.this`, `aws_iam_role.this`, `aws_iam_policy.this`
- `aws_iam_user.this`, `aws_eip.this`, `aws_cloudfront_function.this`
- `aws_secretsmanager_secret.secretsmanager` (exception: uses logical name)

**Descriptive label** — used when the resource has a specific identity:
- `aws_instance.app_server` (ec2 module)
- `aws_s3_bucket.website_s3` (s3 module)
- `aws_security_group.sg_ec2_defaults` (sg module)
- `aws_cloudfront_distribution.cdn_distribution` (cloudfront module)

**Attachment resources** use verb-object labels:
- `aws_iam_role_policy_attachment.attach_managed`
- `aws_iam_user_policy_attachment.attach_managed`

## Module Source Paths

All env configurations reference modules via relative paths from their directory depth:

```hcl
# From envs/frontend/staging/ or envs/frontend/prod/ (3 levels deep)
source = "../../../modules/s3"
source = "../../../modules/cloudfront"

# From envs/strapi/ (2 levels deep)
source = "../../modules/ec2"
source = "../../modules/sg"
```

The iam-policy module references policy templates via a path relative to the module itself:
```hcl
# modules/iam-policy/main.tf
templatefile("${path.module}/../../policies/${t}.tpl", ...)
```

## Module Call Naming

Module instances in env main.tf files use UPPER_SNAKE or Mixed styles:

```hcl
module "S3_Website" { ... }        # primary S3 bucket
module "S3_Website_dist" { ... }   # secondary dist bucket
module "cloudfront" { ... }        # lowercase for cloudfront
module "cloudfront_dist" { ... }   # lowercase with underscore
module "cloudfront_basic_auth" { ... }
module "github_actions_policies" { ... }
module "github_actions_user" { ... }
module "app_secrets" { ... }
module "ec2_instance" { ... }
module "backend_eip" { ... }
```

## Tagging Strategy

Tags are passed as `map(string)` from the env layer down into modules. The `tags` variable always has `default = {}`.

**Pattern at env layer (`terraform.tfvars`):**
```hcl
tags = {
  Env = "staging"    # or "prod"
}
```

**README documents a richer standard that is NOT consistently applied:**
```hcl
tags = {
  App         = "dmair"
  Environment = "prod"
  ManagedBy   = "terraform"
}
```

**In practice, only the `Env` key is used** in all three live `terraform.tfvars` files. `App` and `ManagedBy` tags are absent from actual tfvars.

**Module-level tagging exceptions:**
- `modules/sg/main.tf`: hardcodes `tags = {}` (empty, not using `var.tags`) — security group receives no tags
- `modules/ec2/main.tf`: sets only `Name = "${var.App_Name}-${var.Env_Type}"` inline, ignores a `var.tags` passthrough
- `modules/eip/main.tf`: merges caller tags with a computed `Name` tag:
  ```hcl
  tags = merge(var.tags, { Name = "${var.app_name}-${var.env_type}-eip" })
  ```

**Name tag pattern for named resources:** `${App_Name}-${Env_Type}` (e.g., `dmair-prod`, `dmair-frontend-staging`).

## Variable Defaults and Optionality

The convention for making a variable optional:

**Empty string sentinel** — used for string variables that disable a feature when blank:
```hcl
variable "EC2_AMI" {
  type    = string
  default = ""      # empty string = "not set"
}
# Usage: var.EC2_AMI != "" ? var.EC2_AMI : <computed_value>
```

**`null` default** — used for variables that should produce null behavior when absent:
```hcl
variable "CDN_Default_Root" {
  type    = string
  default = null
}
```

**`false` default** — used for feature-flag booleans:
```hcl
variable "enable_versioning" { default = false }
variable "enable_basic_auth" { default = false }
variable "create_access_key" { default = false }
```

**`{}` default** — used for map/list inputs that are additive:
```hcl
variable "tags"            { default = {} }
variable "policy_arns_map" { default = {} }
variable "egress_rules"    { default = [] }
```

## Conditional Resource Creation

Two patterns are used for conditional resources:

**`count = condition ? 1 : 0`** — for entire resource blocks:
```hcl
resource "aws_s3_bucket_versioning" "this" {
  count  = var.enable_versioning ? 1 : 0
  ...
}
resource "aws_iam_access_key" "this" {
  count = var.create_access_key ? 1 : 0
  ...
}
```

**`dynamic` block with `for_each = condition ? [1] : []`** — for nested blocks:
```hcl
dynamic "function_association" {
  for_each = var.viewer_request_function_arn != "" ? [1] : []
  content { ... }
}
dynamic "viewer_certificate" {
  for_each = var.acm_certificate != "" ? [1] : []
  content { ... }
}
```

## Lifecycle Blocks

Lifecycle blocks are used on production resources to prevent accidental destruction:

**`prevent_destroy = true`** — applied to:
- `modules/ec2/main.tf`: `aws_instance.app_server`
- `modules/cloudfront/main.tf`: `aws_cloudfront_distribution.cdn_distribution`
- `modules/eip/main.tf`: `aws_eip.this`

**`ignore_changes`** — applied to:
- `modules/ec2/main.tf`: ignores `user_data`, `associate_public_ip_address`, `availability_zone`, `ami`, `key_name` (allows post-deploy EC2 changes without drift)
- `modules/sg/main.tf`: ignores `ingress` (allows GitHub Actions to add/remove IPs without triggering drift)

## Resource Naming in AWS

All AWS resource names follow the `${app_name}-${env}` pattern:
```hcl
name = "${var.App_Name}-${var.Env_Type}"   # ec2, sg, secrets_manager
name = lower("${var.APP_NAME}-${var.ENV}") # s3 bucket (forced lowercase)
name = lower("${var.name_prefix}-${each.key}") # iam policies
```

IAM resources (users, policies, roles) always use `lower()` to satisfy AWS naming constraints.

## Policy Template Pattern

IAM policies are defined as `.tpl` files in `policies/` at the repo root. The `iam-policy` module renders them via `templatefile()`. Template variables are passed as a map-of-maps keyed by template name:

```hcl
# modules/iam-policy/main.tf
locals {
  templates = { for t in var.policy_templates : t => templatefile(
    "${path.module}/../../policies/${t}.tpl",
    var.template_vars[t]
  )}
}
```

Templates use HCL's `jsonencode()` function for ARN lists:
```json
"Resource": ${jsonencode(s3_bucket_arns)}
```

Available templates in `policies/`:
- `s3_rw.tpl` — S3 ListBucket + GetObject/PutObject/DeleteObject
- `ecr_push.tpl` — ECR authentication + push operations
- `ecr_pull.tpl` — ECR authentication + pull operations
- `cloudfront_invalidate.tpl` — CloudFront invalidation
- `secrets_manager_read.tpl` — Secrets Manager GetSecretValue + DescribeSecret
- `sg_manage.tpl` — EC2 security group ingress add/revoke
- `ses_send_mail.tpl` — SES SendEmail + SendRawEmail

## Variable Descriptions

Modules have complete descriptions on all variables. Env-level `variables.tf` files are less consistent:
- `envs/strapi/variables.tf`: 20 descriptions out of 37 variables (~54% coverage)
- Variables for S3 CORS config in strapi env omit `description` entirely

**Rule:** Always include `description` on module variables. Env variables should describe non-obvious inputs.

## Variable Validation

Only one `validation` block exists in the entire codebase:
```hcl
# modules/ecr/variables.tf
variable "image_tag_mutability" {
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}
```

Validation blocks are not used for enum-type variables like `EC2_INSTANCE_TYPE` or `ENV`.

## Sensitive Variables and Outputs

Sensitive marking is applied to:
- `modules/secrets_manager/variables.tf`: `secret_string` marked `sensitive = true`
- `modules/iam-user/output.tf`: `access_key_id` and `secret_access_key` marked `sensitive = true`
- `envs/frontend/staging/variables.tf` and `envs/frontend/prod/variables.tf`: `basic_auth_credentials` marked `sensitive = true`
- `envs/strapi/output.tf`: `github_actions_access_key_id` and `github_actions_secret_access_key` marked `sensitive = true`

## Data Sources

Data sources use descriptive names when there is a single instance, or `this` for generic lookups:
- `data.aws_ami.this` — AMI lookup (ec2 module)
- `data.aws_availability_zones.available` — AZ lookup (ec2 module)
- `data.aws_iam_policy_document.s3-policy` — hyphenated, exception (cloudfront module)
- `data.aws_iam_policy_document.assume_ec2` — snake_case (strapi env)

## Comments

Inline comments are used to explain non-obvious configuration choices:

```hcl
owners = ["099720109477"] # Canonical
```
```hcl
# Disable new features to match existing infrastructure
enable_website    = false
```
```hcl
acm_certificate = "" # Use default cloudfront certificate
domain          = "" # No custom domain
```
```hcl
# SES Configuration (commented out - to be configured later)
# module "ses_user" { ... }
```

Commented-out blocks (disabled modules) are left in place with explanatory comments rather than deleted, indicating work-in-progress or future features.

## HCL Formatting

`terraform fmt -recursive` is documented in `envs/strapi/README.md` as the standard formatting tool. All files show consistent `terraform fmt`-style alignment:
- Two-space indentation
- Argument assignment alignment within blocks (values aligned to column)
- Single blank lines between resource blocks
- No trailing whitespace

## Terraform Provider Version Pinning

All three env stacks pin the AWS provider to an exact version:
```hcl
# envs/*/providers.tf
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "5.91.0"   # exact pin, same across all stacks
  }
}
```

There is no `required_version` constraint for the Terraform CLI itself in any configuration.

## State Backend Pattern

Each env uses S3 remote state with hardcoded values (no variable interpolation, as required by Terraform):
```hcl
terraform {
  backend "s3" {
    bucket                   = "dmair-terraform-prod"
    key                      = "frontend/staging/terraform.tfstate"
    region                   = "us-west-2"
    profile                  = "dmair"
    shared_credentials_files = ["~/.aws/credentials"]
  }
}
```

No DynamoDB locking is configured in any backend block (state locking is not enabled).

## Locals Usage

`locals` blocks are used sparingly and only when needed:
- `modules/iam-policy/main.tf`: `locals { templates = {...} }` to build the template map before `for_each`
- `envs/strapi/main.tf`: `locals { startup_user_data = templatefile(...) }` to render the EC2 user-data script before passing to the module

## For Expressions

Complex `for` expressions are used in the iam-policy module locals:
```hcl
{ for t in var.policy_templates : t => templatefile("${path.module}/../../policies/${t}.tpl", var.template_vars[t]) }
```

And in policy templates themselves:
```json
${jsonencode([for arn in s3_bucket_arns : format("%s/*", arn)])}
```

## `count = 1` Anti-Pattern

The sg module uses `count = 1` unconditionally:
```hcl
resource "aws_security_group" "sg_ec2_defaults" {
  count = 1
  ...
}
```
This requires indexed references (`aws_security_group.sg_ec2_defaults[0].id`) throughout. This is an unnecessary use of count — resources without conditional creation should omit count entirely.

---

*Convention analysis: 2026-05-20*
