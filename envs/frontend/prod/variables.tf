variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile"
  default     = "default"
}

variable "aws_credentials_file" {
  type        = list(string)
  default     = ["~/.aws/credentials"]
  description = "AWS credentials file in local"
}

variable "APP_NAME" {
  type        = string
  description = "Application name"
}

variable "ENV" {
  type        = string
  description = "Application Env type"
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default = {
    Environment = "develop"
  }
}

variable "S3_cors_Allowed_Headers" {
  type        = list(string)
  description = "S3 cors Allowed Headers"
  default     = ["*"]
}

variable "S3_cors_Allowed_Methods" {
  type        = list(string)
  description = "S3 cors Allowed Methods"
  default     = ["GET"]
}

variable "S3_cors_Allowed_Origins" {
  type        = list(string)
  description = "S3 cors Allowed origins"
  default     = ["*"]
}

variable "S3_cors_Expose_Headers" {
  type        = list(string)
  description = "S3 cors expose headers"
  default     = ["ETag"]
}

variable "S3_cors_Max_Age" {
  type        = number
  description = "S3 cors max age in seconds"
  default     = 3000
}

variable "WEBSITE_index_file" {
  type        = string
  description = "default index file of the website"
  default     = "index.html"
}

variable "WEBSITE_error_file" {
  type        = string
  description = "default error file of the website"
  default     = "error.html"
}

variable "AWS_S3_Bucket_ACL_TYPE" {
  type        = string
  description = "AWS S3 Bucket ACL TYPE"
  default     = "private"
}

variable "AWS_S3_block_public_acls" {
  type        = bool
  description = "AWS S3 block_public_acls"
  default     = true
}

variable "AWS_S3_block_public_policy" {
  type        = bool
  description = "AWS S3 block_public_policy"
  default     = true
}

variable "AWS_S3_ignore_public_acls" {
  type    = bool
  default = true
}

variable "AWS_S3_restrict_public_buckets" {
  type        = bool
  description = "AWS S3 restrict_public_buckets"
  default     = true
}

variable "S3_Origin_ID" {
  type        = string
  description = "Default Website s3 Origin ID"
  default     = "S3WebHosting"
}

variable "CDN_Default_Root" {
  type        = string
  description = "Default root object of cloudfront"
  default     = "index.html"
}

variable "CDN_Allowed_Methods" {
  type        = list(string)
  description = "Cloudfront Allowed Methods"
  default     = ["GET"]
}

variable "CDN_Cached_Methods" {
  type        = list(string)
  description = "Cloudfront Cached Methods"
  default     = ["GET", "HEAD"]
}

variable "CDN_Custom_Error_Response" {
  type        = string
  description = "Default root object of cloudfront"
  default     = "/index.html"
}

variable "CDN_Describtion" {
  type        = string
  description = "Describtion for cloudfront resource"
  default     = "S3WebHosting"
}

variable "domain" {
  type        = string
  default     = ""
  description = "custom domain name to add cloudfront"
}

variable "acm_certificate" {
  type        = string
  description = "ACM certificate ARN for CloudFront (in us-east-1)"
  default     = ""
}

variable "website_s3_bucket" {
  type        = string
  description = "AWS s3 bucket for hosting"
}

variable "Jenkins_IAM_User" {
  type        = string
  description = "Optional override for the Jenkins IAM user name. If null, it will default to APP_NAME-ENV-jenkins-user"
  default     = null
}

variable "hosted_zone_name" {
  description = "Route53 public hosted zone name (e.g., dev.sayone.team)"
  type        = string
  default     = "dev.sayone.team"
}

variable "enable_basic_auth" {
  description = "Enable basic authentication on CloudFront"
  type        = bool
  default     = false
}

variable "basic_auth_credentials" {
  description = "Base64 encoded basic auth credentials (format: base64(username:password))"
  type        = string
  default     = ""
  sensitive   = true
}
