variable "s3_domain" {
  type        = string
  description = "S3 bucket domain name"
}

variable "s3_regional_domain" {
  type        = string
  description = "S3 bucket regional domain name"
}

variable "s3_arn" {
  type        = string
  description = "S3 bucket ARN"
}

variable "s3_name" {
  type        = string
  description = "S3 bucket name"
}

variable "APP_NAME" {
  type        = string
  description = "Application name"
}

variable "ENV" {
  type        = string
  description = "Environment"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "S3_Origin_ID" {
  type        = string
  description = "S3 origin ID"
  default     = "S3-Origin"
}

variable "CDN_Default_Root" {
  type        = string
  description = "Default root object"
  default     = null
}

variable "CDN_Allowed_Methods" {
  type        = list(string)
  description = "Allowed methods"
  default     = null
}

variable "CDN_Cached_Methods" {
  type        = list(string)
  description = "Cached methods"
  default     = null
}

variable "CDN_Custom_Error_Response" {
  type        = string
  description = "Custom error response page"
  default     = null
}

variable "CDN_Describtion" {
  type        = string
  description = "CloudFront distribution description"
  default     = "CloudFront Distribution"
}

variable "domain" {
  type        = string
  description = "Custom domain name"
  default     = ""
}

variable "acm_certificate" {
  type        = string
  description = "ACM certificate ARN"
  default     = ""
}

variable "viewer_request_function_arn" {
  type        = string
  description = "ARN of CloudFront function to attach to viewer-request event (e.g., for basic auth)"
  default     = ""
}
