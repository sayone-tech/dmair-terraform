module "S3_Website" {
  source = "../../../modules/s3"
  #Env variables
  APP_NAME                       = var.APP_NAME
  ENV                            = var.ENV
  tags                           = var.tags
  S3_cors_Allowed_Headers        = var.S3_cors_Allowed_Headers
  S3_cors_Allowed_Methods        = var.S3_cors_Allowed_Methods
  S3_cors_Allowed_Origins        = var.S3_cors_Allowed_Origins
  S3_cors_Expose_Headers         = var.S3_cors_Expose_Headers
  S3_cors_Max_Age                = var.S3_cors_Max_Age
  WEBSITE_index_file             = var.WEBSITE_index_file
  WEBSITE_error_file             = var.WEBSITE_error_file
  AWS_S3_Bucket_ACL_TYPE         = var.AWS_S3_Bucket_ACL_TYPE
  AWS_S3_block_public_acls       = var.AWS_S3_block_public_acls
  AWS_S3_block_public_policy     = var.AWS_S3_block_public_policy
  AWS_S3_ignore_public_acls      = var.AWS_S3_ignore_public_acls
  AWS_S3_restrict_public_buckets = var.AWS_S3_restrict_public_buckets

  # Disable new features to match existing infrastructure
  enable_website    = false
  enable_versioning = false
  enable_encryption = true

}

# CloudFront Function for URL Rewriting (production - no auth)
module "cloudfront_url_rewrite" {
  source = "../../../modules/cloudfront-function"

  app_name      = var.APP_NAME
  env           = var.ENV
  function_name = "url-rewrite"
  function_file = "url_rewrite.js"

  function_vars = {}
}

module "cloudfront" {
  source = "../../../modules/cloudfront"

  #variables from s3
  s3_domain          = module.S3_Website.S3-Bucket-Domain
  s3_regional_domain = module.S3_Website.S3-Bucket-Domain
  s3_arn             = module.S3_Website.S3-Bucket-ARN
  s3_name            = module.S3_Website.S3-Bucket-NAME
  #Env variables
  APP_NAME                  = var.APP_NAME
  ENV                       = var.ENV
  tags                      = var.tags
  S3_Origin_ID              = var.S3_Origin_ID
  CDN_Default_Root          = var.CDN_Default_Root
  CDN_Allowed_Methods       = var.CDN_Allowed_Methods
  CDN_Cached_Methods        = var.CDN_Cached_Methods
  CDN_Custom_Error_Response = var.CDN_Custom_Error_Response
  CDN_Describtion           = var.CDN_Describtion
  acm_certificate           = var.acm_certificate
  domain                    = var.domain

  # Attach CloudFront function for URL rewriting
  viewer_request_function_arn = module.cloudfront_url_rewrite.function_arn
}

module "secrets_manager" {
  source   = "../../../modules/secrets_manager"
  App_Name = var.APP_NAME
  Env_Type = var.ENV
}

# GitHub Actions IAM user using template-based policies
module "github_actions_policies" {
  source      = "../../../modules/iam-policy"
  name_prefix = lower("${var.APP_NAME}-${var.ENV}-github-actions")
  policy_templates = [
    "s3_rw",
    "cloudfront_invalidate",
    "secrets_manager_read"
  ]
  template_vars = {
    s3_rw = {
      s3_bucket_arns = [module.S3_Website.S3-Bucket-ARN]
    }
    cloudfront_invalidate = {
      cloudfront_distribution_arns = [module.cloudfront.cdn_distribution_arn]
    }
    secrets_manager_read = {
      secretsmanager_arns = [module.secrets_manager.secretsmanager_arn]
    }
  }
  tags = var.tags
}


module "github_actions_user" {
  source    = "../../../modules/iam-user"
  user_name = lower("${var.APP_NAME}-${var.ENV}-github-actions-user")
  app_name  = var.APP_NAME
  env       = var.ENV
  tags      = var.tags

  policy_arns_map = merge(
    module.github_actions_policies.policy_arns_map
  )
}
