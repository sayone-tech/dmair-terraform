# platform/oidc/variables.tf

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-west-2"
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
  description = "OIDC sub-claim patterns allowed to assume the plan-readonly role."
  type        = list(string)
  default = [
    "pull_request",
    "ref:refs/heads/main",
  ]
}

variable "staging_apply_subjects" {
  description = "OIDC sub-claim patterns allowed to assume the staging-apply role."
  type        = list(string)
  default = [
    "ref:refs/heads/main",
  ]
}

variable "prod_apply_subjects" {
  description = "OIDC sub-claim patterns allowed to assume the prod-apply role (gated by the 'prod' GitHub Environment)."
  type        = list(string)
  default = [
    "environment:prod",
  ]
}

variable "state_bucket_arn" {
  description = "ARN of the Terraform state bucket — used in the scoped IAM policy templates."
  type        = string
  default     = "arn:aws:s3:::dmair-terraform-prod"
}
