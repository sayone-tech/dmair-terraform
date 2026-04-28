variable "user_name" {
  type        = string
  description = "IAM user name"
}

variable "app_name" {
  type        = string
  description = "Application name (kept for compatibility; not used)"
  default     = ""
}

variable "env" {
  type        = string
  description = "Environment (kept for compatibility; not used)"
  default     = ""
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}

variable "create_access_key" {
  description = "Whether to create an access key for the user"
  type        = bool
  default     = false
}

variable "policy_arns_map" {
  description = "Map of managed policy ARNs to attach to the user (keys should be static)"
  type        = map(string)
  default     = {}
}
