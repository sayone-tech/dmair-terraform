variable "role_name" {
  type        = string
  description = "IAM role name"
}

variable "assume_role_policy" {
  type        = string
  description = "JSON assume role policy document"
}

variable "policy_arns_map" {
  description = "Map of managed policy ARNs to attach to the role (keys should be static)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
