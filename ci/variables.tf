# ci/variables.tf — inputs for the terraform CI IAM roles.

variable "aws_region" {
  description = "AWS region (only us-west-2 is supported)."
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "Local AWS profile. CI itself doesn't use this — it assumes a role via OIDC."
  type        = string
  default     = "dmair"
}

variable "aws_credentials_file" {
  description = "Shared credentials file path(s)."
  type        = list(string)
  default     = ["~/.aws/credentials"]
}

variable "github_org" {
  description = "GitHub org owning the dmair-terraform repository."
  type        = string
  default     = "sayone-tech"
}

variable "github_repo" {
  description = "GitHub repository name for this Terraform monorepo."
  type        = string
  default     = "dmair-terraform"
}

variable "plan_subjects" {
  description = "OIDC sub-claim patterns allowed to assume the plan-readonly role. Includes all pull-request runs and pushes to main."
  type        = list(string)
  default = [
    "pull_request",
    "ref:refs/heads/main",
  ]
}

variable "staging_apply_subjects" {
  description = "OIDC sub-claim patterns allowed to assume the staging-apply role. Restricted to push to main."
  type        = list(string)
  default = [
    "ref:refs/heads/main",
  ]
}

variable "prod_apply_subjects" {
  description = "OIDC sub-claim patterns allowed to assume the prod-apply role. Restricted to push to main from the 'prod' environment (GitHub Environments gate)."
  type        = list(string)
  default = [
    "environment:prod",
  ]
}

variable "state_bucket_arn" {
  description = "ARN of the Terraform state bucket — used in the scoped state-read/write IAM permissions."
  type        = string
  default     = "arn:aws:s3:::dmair-terraform-prod"
}
