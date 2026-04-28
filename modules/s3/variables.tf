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

variable "enable_website" {
  type        = bool
  description = "Enable S3 website hosting"
  default     = true
}

variable "enable_encryption" {
  type        = bool
  description = "Enable S3 server-side encryption"
  default     = true
}

variable "enable_versioning" {
  type        = bool
  description = "Enable S3 bucket versioning"
  default     = false
}

variable "S3_cors_Allowed_Headers" {
  type        = list(string)
  description = "S3 CORS allowed headers"
  default     = ["*"]
}

variable "S3_cors_Allowed_Methods" {
  type        = list(string)
  description = "S3 CORS allowed methods"
  default     = ["GET"]
}

variable "S3_cors_Allowed_Origins" {
  type        = list(string)
  description = "S3 CORS allowed origins"
  default     = ["*"]
}

variable "S3_cors_Expose_Headers" {
  type        = list(string)
  description = "S3 CORS expose headers"
  default     = ["ETag"]
}

variable "S3_cors_Max_Age" {
  type        = number
  description = "S3 CORS max age in seconds"
  default     = 3000
}

variable "WEBSITE_index_file" {
  type        = string
  description = "Default index file for website"
  default     = "index.html"
}

variable "WEBSITE_error_file" {
  type        = string
  description = "Default error file for website"
  default     = "error.html"
}

variable "AWS_S3_Bucket_ACL_TYPE" {
  type        = string
  description = "S3 bucket ACL type"
  default     = "private"
}

variable "AWS_S3_block_public_acls" {
  type        = bool
  description = "Block public ACLs"
  default     = true
}

variable "AWS_S3_block_public_policy" {
  type        = bool
  description = "Block public policy"
  default     = true
}

variable "AWS_S3_ignore_public_acls" {
  type        = bool
  description = "Ignore public ACLs"
  default     = true
}

variable "AWS_S3_restrict_public_buckets" {
  type        = bool
  description = "Restrict public buckets"
  default     = true
}
