variable "app_name" {
  type        = string
  description = "Application name"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "function_name" {
  type        = string
  description = "CloudFront function name suffix"
}

variable "function_file" {
  type        = string
  description = "Path to the function file (relative to module directory)"
}

variable "function_vars" {
  type        = map(any)
  description = "Variables to pass to the function template"
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

