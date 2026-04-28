variable "App_Name" {
  type        = string
  description = "Application name"
}

variable "Env_Type" {
  type        = string
  description = "Environment type"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "recovery_window_in_days" {
  type        = number
  description = "Recovery window in days"
  default     = 0
}

variable "secret_string" {
  type        = string
  description = "Secret string value"
  default     = null
  sensitive   = true
}
