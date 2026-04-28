variable "App_Name" {
  type        = string
  description = "Application name"
}

variable "Env_Type" {
  type        = string
  description = "Environment type"
}

variable "Github_Actions_IP" {
  type        = string
  description = "GitHub Actions Runner IP CIDR"
  default     = "34.136.212.252/32"
}

variable "Jenkins_IP" {
  type        = string
  description = "Jenkins Server IP CIDR (for SSH access)"
  default     = ""
}


variable "use_default_rules" {
  type        = bool
  description = "Whether to use default HTTP/HTTPS/SSH rules"
  default     = true
}

variable "ingress_rules" {
  description = "Custom ingress rules"
  type = list(object({
    description      = string
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = list(string)
    ipv6_cidr_blocks = list(string)
    security_groups  = list(string)
  }))
  default = []
}

variable "egress_rules" {
  description = "Custom egress rules"
  type = list(object({
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = list(string)
    ipv6_cidr_blocks = list(string)
    security_groups  = list(string)
  }))
  default = []
}
