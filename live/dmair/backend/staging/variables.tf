# live/dmair/backend/staging/variables.tf
#
# Variables for the dmair-backend staging stack. Defaults mirror the spec in
# `DMAir/dmair-backend/deployment/staging/STAGING-DEPLOYMENT.md`.
#
# Sensitive values (db_password, jwt_secret_key, mail_password,
# admin_bootstrap_password) are NOT variables. They are fetched at terraform
# plan/apply time from AWS SSM Parameter Store — see ssm.tf for the data
# sources and the put-parameter setup commands in DEVOPS-HANDOFF.md.

variable "aws_region" {
  description = "AWS region. us-west-2 is the only supported value at the moment."
  type        = string
  default     = "us-west-2"
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
  description = "PostgreSQL major version."
  type        = string
  default     = "17"
}

variable "db_allocated_storage" {
  description = "Initial DB storage in GB. gp3."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Storage autoscale ceiling in GB. RDS scales up to this value when usage approaches allocated_storage."
  type        = number
  default     = 30
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

variable "db_backup_retention_days" {
  description = "Automated backup retention in days. 3 keeps backup storage well within the free allocation when allocated_storage = 20."
  type        = number
  default     = 3
}

# --- App image ------------------------------------------------------------

variable "app_image" {
  description = "Full ECR image URI incl. tag (e.g. 071297531943.dkr.ecr.us-west-2.amazonaws.com/dmair-backend:<sha>). Default targets the current staging-latest tag so a no-tfvars apply (CI) pulls a valid image; override with a pinned :<sha> for deterministic deploys."
  type        = string
  default     = "071297531943.dkr.ecr.us-west-2.amazonaws.com/dmair-backend:staging-latest"

  # Guardrail (STATE.md 'Lessons & Guardrails' #1): reject a bare tag. CI and
  # -replace run with no local tfvars and fall back to this default, so a bare
  # "staging-latest" would silently resolve to docker.io/library/staging-latest
  # and the app container could not start on a fresh instance.
  validation {
    condition     = can(regex("\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+:.+", var.app_image))
    error_message = "app_image must be a FULL ECR image URI (<acct>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>), not a bare tag."
  }
}

# --- Domain ---------------------------------------------------------------

variable "staging_domain" {
  description = "Public hostname for the staging backend. Caddy obtains a Let's Encrypt cert for this name."
  type        = string
  default     = "staging-api.flydmair.com"
}

variable "staging_frontend_origin" {
  description = "Browser origin of the staging dashboard SPA that calls the backend API (CORS)."
  type        = string
  default     = "https://staging-dashboard.flydmair.com"
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

# CI / OIDC variables intentionally removed — the dmair-backend-staging-
# deploy role is created out-of-band by ops (see docs/iam-oidc/), not by
# Terraform.
