variable "App_Name" {
  type        = string
  description = "Application name"
}

variable "Env_Type" {
  type        = string
  description = "Environment type"
}

variable "EC2_AMI_FILTER" {
  type        = string
  description = "AMI filter for automatic selection"
  default     = ""
}

variable "EC2_AMI" {
  type        = string
  description = "Specific AMI ID to use"
  default     = ""
}

variable "EC2_INSTANCE_TYPE" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "EC2_PRIVATE_KEY" {
  type        = string
  description = "EC2 key pair name"
  default     = ""
}

variable "EC2_AZ" {
  type        = string
  description = "Availability zone"
  default     = ""
}

variable "EC2_SG_ID" {
  type        = string
  description = "Security group ID"
}

variable "IAM_PROFILE" {
  type        = string
  description = "IAM instance profile name"
}

variable "EC2_USER_DATA_CONTENT" {
  type        = string
  description = "User data script content"
  default     = ""
}

variable "EC2_ROOT_VOLUME_TYPE" {
  type        = string
  description = "Root volume type"
  default     = "gp3"
}

variable "EC2_ROOT_VOLUME_SIZE" {
  type        = number
  description = "Root volume size in GB"
  default     = 20
}

variable "EC2_CPU_CREDITS" {
  type        = string
  description = "CPU credits for burstable instances"
  default     = "standard"
}
