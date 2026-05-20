# Testing Patterns

**Analysis Date:** 2026-05-20

## Test Framework

**Automated Test Runner:** None detected.

No Terratest, `pytest-terraform`, `kitchen-terraform`, `tflint`, `checkov`, `tfsec`, `trivy`, `infracost`, `conftest`, or any other automated test/lint tooling is present in this repository. There are no test files, no test configuration files, and no CI/CD pipeline definitions (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, etc.).

**Documented manual checks only:**

The validation workflow described in `envs/strapi/README.md` defines the intended process:

```bash
# 1. Validate HCL syntax
terraform validate

# 2. Format check
terraform fmt -recursive

# 3. Security scan (requires manual tfsec install)
tfsec .

# 4. Plan before apply
terraform plan -out=tfplan

# 5. Apply from plan file
terraform apply tfplan
```

## Terraform Validate

`terraform validate` is the only automated correctness check mentioned. It validates:
- HCL syntax correctness
- Provider schema compliance
- Variable reference resolution
- Resource attribute types

**How to run per environment:**
```bash
cd /Users/mithin/Projects/DMAir/dmair-terraform/envs/strapi
terraform init
terraform validate

cd /Users/mithin/Projects/DMAir/dmair-terraform/envs/frontend/staging
terraform init
terraform validate

cd /Users/mithin/Projects/DMAir/dmair-terraform/envs/frontend/prod
terraform init
terraform validate
```

Note: `terraform validate` requires `terraform init` to have been run first (provider plugins must be present). Each env must be validated independently since they are separate Terraform root modules.

## Terraform Plan Review

The documented pre-apply process (`envs/strapi/README.md` Best Practices #1) mandates reviewing `terraform plan` output before every `terraform apply`. This is the primary change-safety mechanism:

```bash
# Plan with output file (recommended)
terraform plan -out=tfplan

# Review the plan, then apply from the saved plan file
terraform apply tfplan
```

This prevents `terraform apply` from processing any changes that differ from what was reviewed.

**Targeted plan** for partial updates:
```bash
terraform plan -target=module.ec2_instance
terraform plan -target=module.cloudfront
```

## Formatting Verification

`terraform fmt -recursive` is documented as the formatting standard. Run from the repo root to enforce consistent HCL formatting across all files:

```bash
cd /Users/mithin/Projects/DMAir/dmair-terraform
terraform fmt -recursive

# Check mode (non-zero exit if any file needs reformatting)
terraform fmt -check -recursive
```

## Security Scanning

`tfsec` is referenced in `envs/strapi/README.md` but is not installed, configured, or enforced anywhere in the repository. No `.tfsec/` config directory or `tfsec.yml` exists.

**Referenced command (not yet operational):**
```bash
tfsec .
```

**To add tfsec scanning:**
```bash
# Install tfsec
brew install tfsec  # macOS

# Run from repo root
tfsec /Users/mithin/Projects/DMAir/dmair-terraform
```

## Pre-Apply Deployment Checklist

The documented workflow from `envs/strapi/README.md` and `GITHUB_ACTIONS_SETUP.md`:

1. Run `terraform init` (on first use or after provider changes)
2. Run `terraform validate` (syntax check)
3. Run `terraform fmt -check` (formatting check)
4. Run `terraform plan -out=tfplan` (review all changes)
5. Run `terraform apply tfplan` (apply reviewed plan)
6. Run `terraform output` to verify post-apply state

## State Integrity Checks

No automated state integrity checking. Manual steps documented:

```bash
# List current state resources
terraform state list

# Show specific resource state
terraform state show module.ec2_instance.aws_instance.app_server

# Verify outputs after apply
terraform output
terraform output -raw eip_public_ip
terraform output -raw github_actions_access_key_id
```

## State Locking

**State locking is NOT enabled.** All three backend configurations omit `dynamodb_table`:
```hcl
# envs/strapi/backend.tf — NO dynamodb_table key
terraform {
  backend "s3" {
    bucket  = "dmair-terraform-prod"
    key     = "strapi/terraform.tfstate"
    region  = "us-west-2"
    profile = "dmair"
  }
}
```

Concurrent `terraform apply` runs from multiple operators or CI jobs could corrupt state. The `.planning/seeds/phase-09-context.md` document identifies this as a known gap to be resolved by adding a DynamoDB lock table.

## CI/CD Integration

**No CI/CD pipeline exists.** There are no GitHub Actions workflows, Jenkins pipelines, or any other automation that runs `terraform plan`, `terraform validate`, or security scans on pull requests.

The `GITHUB_ACTIONS_SETUP.md` documents a GitHub Actions workflow for deploying the **application** (Docker/EC2 deployment) — not for running Terraform CI checks.

**The intended manual CI process** (from README best practices):
1. Always run `terraform plan` before `apply`
2. Use version control for `.tf` files
3. Never commit `terraform.tfvars` with secrets
4. Use remote state for team collaboration
5. Test in dev before applying to production

## Module Testing

No module-level tests exist. Modules in `modules/` have only:
- `main.tf` — resource definitions
- `variables.tf` — input declarations
- `output.tf` — output declarations
- `README.md` — auto-generated `terraform-docs` output (using `<!-- BEGIN_TF_DOCS -->` markers)

No `examples/` directories, no Terratest Go tests, no `test/` directories.

## Destroy Safety

Three production resources have `lifecycle { prevent_destroy = true }`:
- `modules/ec2/main.tf`: `aws_instance.app_server`
- `modules/cloudfront/main.tf`: `aws_cloudfront_distribution.cdn_distribution`
- `modules/eip/main.tf`: `aws_eip.this`

These act as a guardrail against accidental `terraform destroy`. To remove a protected resource, you must first edit the module to set `prevent_destroy = false`, then run `terraform apply` to register the lifecycle change, then run `terraform destroy`.

## Documentation Generation

Module README files are auto-generated using `terraform-docs` (evidenced by the `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` markers in all `modules/*/README.md` files). The tool is not present in the repo configuration, but the pattern is established.

**To regenerate docs:**
```bash
# Install terraform-docs
brew install terraform-docs  # macOS

# Generate for a specific module
terraform-docs markdown table /Users/mithin/Projects/DMAir/dmair-terraform/modules/ec2

# Update in place (appends/replaces between markers)
terraform-docs markdown table --output-file README.md /Users/mithin/Projects/DMAir/dmair-terraform/modules/ec2
```

## Recommended Testing to Add

Based on the current state, the following tooling would fill the gaps:

**Minimum viable CI (`.github/workflows/terraform-ci.yml`):**
```yaml
- terraform fmt -check -recursive         # formatting gate
- terraform validate                       # syntax gate (per env)
- tflint --recursive                       # best-practice linting
```

**Security scanning:**
```bash
tfsec /Users/mithin/Projects/DMAir/dmair-terraform     # security issues
checkov -d /Users/mithin/Projects/DMAir/dmair-terraform  # compliance rules
```

**State locking:**
```hcl
# Add to each backend.tf
dynamodb_table = "dmair-terraform-locks"
```

---

*Testing analysis: 2026-05-20*
