variable "app_name" {
  type        = string
  description = "Application name for resource naming"
}

variable "env_type" {
  type        = string
  description = "Environment type (e.g., dev, staging, prod)"
}

variable "instance_id" {
  type        = string
  description = "EC2 instance ID to associate with the Elastic IP"
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the Elastic IP"
  default     = {}
}

variable "associate_with_instance" {
  type        = bool
  description = "Whether to explicitly associate the EIP with the instance (usually not needed)"
  default     = false
}
