variable "name_prefix" {
  description = "Prefix for managed policy names"
  type        = string
}

variable "policy_templates" {
  description = "List of policy template names (without .tpl extension)"
  type        = list(string)
}

variable "template_vars" {
  description = "Map of variables per template name for templatefile rendering"
  type        = map(any)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
