# live/dmair/staging/backend/variables.tf
#
# Variables for the dmair-backend staging stack. Defaults mirror the spec in
# `DMAir/dmair-backend/deployment/staging/STAGING-DEPLOYMENT.md` (commit-time
# snapshot of that doc lives in our DEVOPS-HANDOFF.md for review).
#
# Secret values (db_password, jwt_secret_key, mail_password,
# admin_bootstrap_password) MUST be supplied via TF_VAR_<name> environment
# variables (or a gitignored `staging.auto.tfvars`) — they are never committed.

variable "aws_region" {
  description = "AWS region. us-west-2 is the only supported value at the moment."
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "Local AWS named profile resolved from shared credentials. CI assumes a role via OIDC and ignores this."
  type        = string
  default     = "dmair"
}

variable "aws_credentials_file" {
  description = "Path(s) to the AWS shared credentials file."
  type        = list(string)
  default     = ["~/.aws/credentials"]
}

# --- Networking -----------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR for the dedicated dmair-staging VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "web_ingress_cidrs" {
  description = "CIDRs allowed on TCP 80 + 443 to the EC2 instance. Default open; tighten before exposing real data."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- Compute --------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type. t4g.medium = 2 vCPU ARM Graviton + 4 GB RAM."
  type        = string
  default     = "t4g.medium"
}

variable "key_pair_name" {
  description = "Optional break-glass SSH key-pair name. Primary access is SSM Session Manager."
  type        = string
  default     = null
}

# --- Database -------------------------------------------------------------

variable "db_instance_class" {
  description = "RDS instance class. db.t4g.micro = 2 vCPU ARM + 1 GB RAM."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL major version. 16 is the spec target."
  type        = string
  default     = "16"
}

variable "db_allocated_storage" {
  description = "Initial DB storage in GB. gp3."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Logical database name created inside the RDS instance."
  type        = string
  default     = "dmair"
}

variable "db_username" {
  description = "RDS master/app user name."
  type        = string
  default     = "dmair_app"
}

variable "db_password" {
  description = "RDS master/app password. Supply via TF_VAR_db_password — never commit."
  type        = string
  sensitive   = true
}

variable "db_backup_retention_days" {
  description = "Automated backup retention in days. 7 fits within free backup-storage allocation when allocated_storage = 20."
  type        = number
  default     = 7
}

# --- Secrets --------------------------------------------------------------

variable "jwt_secret_key" {
  description = "JWT signing key (HS512, >=64 chars). Supply via TF_VAR_jwt_secret_key."
  type        = string
  sensitive   = true
}

variable "mail_password" {
  description = "SendGrid API key (Mail password). Supply via TF_VAR_mail_password."
  type        = string
  sensitive   = true
}

variable "admin_bootstrap_password" {
  description = "Initial admin bootstrap password (12-128 chars). Supply via TF_VAR_admin_bootstrap_password."
  type        = string
  sensitive   = true
}

# --- App image ------------------------------------------------------------

variable "app_image" {
  description = "Full ECR image URI incl. tag (e.g. 071297531943.dkr.ecr.us-west-2.amazonaws.com/dmair-backend:<sha>). First apply may use 'staging-latest' before the first image is pushed."
  type        = string
  default     = "staging-latest"
}

# --- Domain ---------------------------------------------------------------

variable "staging_domain" {
  description = "Public hostname for the staging backend. Caddy obtains a Let's Encrypt cert for this name."
  type        = string
  default     = "api-staging.flydmair.com"
}

# --- Cost alarm -----------------------------------------------------------

variable "budget_monthly_cap_usd" {
  description = "Hard cap for AWS Budget actual-cost alarm on the dmair-staging stack (USD/month)."
  type        = number
  default     = 60
}

variable "budget_alert_email" {
  description = "Email address receiving the 80%-of-cap alert from AWS Budgets."
  type        = string
  default     = "ops@flydmair.com"
}

# --- CI / OIDC ------------------------------------------------------------

variable "github_org" {
  description = "GitHub org owning the dmair-backend repository (used in OIDC trust subject claims)."
  type        = string
  default     = "sayone-tech"
}

variable "github_repo" {
  description = "GitHub repository for the backend application."
  type        = string
  default     = "dmair-backend"
}

variable "github_deploy_branches" {
  description = "Refs that may assume the dmair-backend-staging-deploy role. Restrict to staging-track refs."
  type        = list(string)
  default = [
    "ref:refs/heads/staging",
    "environment:staging",
  ]
}
