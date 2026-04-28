
module "app_s3_bucket" {
  source = "../../modules/s3"

  APP_NAME = "${var.APP_NAME}-cms"
  ENV      = var.ENV
  tags     = var.tags

  # Disable website hosting for backend bucket
  enable_website = false

  # Keep sensible CORS defaults; adjust if needed
  S3_cors_Allowed_Headers = var.S3_cors_Allowed_Headers
  S3_cors_Allowed_Methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
  S3_cors_Allowed_Origins = var.S3_cors_Allowed_Origins
  S3_cors_Expose_Headers  = var.S3_cors_Expose_Headers
  S3_cors_Max_Age         = var.S3_cors_Max_Age

  AWS_S3_Bucket_ACL_TYPE         = var.AWS_S3_Bucket_ACL_TYPE
  AWS_S3_block_public_acls       = var.AWS_S3_block_public_acls
  AWS_S3_block_public_policy     = var.AWS_S3_block_public_policy
  AWS_S3_restrict_public_buckets = var.AWS_S3_restrict_public_buckets
}

module "app_secrets" {
  source   = "../../modules/secrets_manager"
  App_Name = "${var.APP_NAME}-cms"
  Env_Type = var.ENV
}

# CloudFront distribution in front of the backend S3 bucket
module "cloudfront" {
  source = "../../modules/cloudfront"

  # from S3
  s3_domain          = module.app_s3_bucket.S3-Bucket-Domain
  s3_regional_domain = module.app_s3_bucket.S3-Bucket-Domain
  s3_arn             = module.app_s3_bucket.S3-Bucket-ARN
  s3_name            = module.app_s3_bucket.S3-Bucket-NAME

  # env
  APP_NAME            = var.APP_NAME
  ENV                 = var.ENV
  tags                = var.tags
  S3_Origin_ID        = "${var.APP_NAME}-${var.ENV}-S3-Origin-ID"
  CDN_Allowed_Methods = ["GET", "HEAD"]
  CDN_Cached_Methods  = ["GET", "HEAD"]
  CDN_Describtion     = "BackendS3CDN"

  acm_certificate = var.acm_certificate
  domain          = var.cdn_domain
}


module "app_ecr" {
  source               = "../../modules/ecr"
  repository_name      = lower("${var.APP_NAME}-${var.ENV}")
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  tags                 = var.tags
}

module "github_actions_policies" {
  source      = "../../modules/iam-policy"
  name_prefix = lower("${var.APP_NAME}-${var.ENV}-github-actions")
  policy_templates = [
    "ecr_push",
    "secrets_manager_read",
    "cloudfront_invalidate",
    "sg_manage"
  ]
  template_vars = {
    ecr_push = {
      ecr_repository_arns = [module.app_ecr.repository_arn]
    }
    secrets_manager_read = {
      secretsmanager_arns = [module.app_secrets.secretsmanager_arn]
    }
    cloudfront_invalidate = {
      cloudfront_distribution_arns = [module.cloudfront.cdn_distribution_arn]
    }
    sg_manage = {
      security_group_arn = [module.sg.sg_arn]
    }
  }
  tags = var.tags
}


module "github_actions_user" {
  source    = "../../modules/iam-user"
  user_name = lower("${var.APP_NAME}-${var.ENV}-github-actions-user")
  app_name  = var.APP_NAME
  env       = var.ENV
  tags      = var.tags

  policy_arns_map = merge(
    module.github_actions_policies.policy_arns_map
  )
}

# App IAM user for programmatic S3 access from Strapi
module "app_user_policies" {
  source      = "../../modules/iam-policy"
  name_prefix = lower("${var.APP_NAME}-${var.ENV}-app-user")
  policy_templates = [
    "s3_rw",
    "cloudfront_invalidate"
  ]
  template_vars = {
    s3_rw = {
      s3_bucket_arns = [module.app_s3_bucket.S3-Bucket-ARN]
    }
    cloudfront_invalidate = {
      cloudfront_distribution_arns = [module.cloudfront.cdn_distribution_arn]
    }
  }
  tags = var.tags
}

module "app_user" {
  source    = "../../modules/iam-user"
  user_name = lower("${var.APP_NAME}-${var.ENV}-app-user")
  app_name  = var.APP_NAME
  env       = var.ENV
  tags      = var.tags

  policy_arns_map = merge(
    module.app_user_policies.policy_arns_map
  )
}

# SES IAM user for sending emails from Strapi
# module "ses_user_policies" {
#   source      = "../../modules/iam-policy"
#   name_prefix = lower("${var.APP_NAME}-${var.ENV}-ses-user")
#   policy_templates = [
#     "ses_send_mail"
#   ]
#   template_vars = {
#     ses_send_mail = {
#       ses_resource_arns = var.ses_identity_arn
#     }
#   }
#   tags = var.tags
# }

# module "ses_user" {
#   source    = "../../modules/iam-user"
#   user_name = lower("${var.APP_NAME}-${var.ENV}-ses-user")
#   app_name  = var.APP_NAME
#   env       = var.ENV
#   tags      = var.tags

#   policy_arns_map = merge(
#     module.ses_user_policies.policy_arns_map
#   )
# }

# EC2 IAM Role managed policies
module "app_role_policies" {
  source      = "../../modules/iam-policy"
  name_prefix = lower("${var.APP_NAME}-${var.ENV}-app")
  policy_templates = concat(
    [
      "ecr_pull",
      "cloudfront_invalidate",
      "s3_rw"
    ]
    # SES policy disabled
    # length(var.ses_identity_arn) > 0 ? ["ses_send_mail"] : []
  )
  template_vars = merge(
    {
      ecr_pull = {
        ecr_repository_arns = [module.app_ecr.repository_arn]
      }
      s3_rw = {
        s3_bucket_arns = [
          module.app_s3_bucket.S3-Bucket-ARN,
          "arn:aws:s3:::dmair-strapi-s3-backup",
          "arn:aws:s3:::dmair-strapi-s3-backup/*"
        ]
      }
      cloudfront_invalidate = {
        cloudfront_distribution_arns = [module.cloudfront.cdn_distribution_arn]
      }
    }
    # SES template vars disabled
    # length(var.ses_identity_arn) > 0 ? {
    #   ses_send_mail = {
    #     ses_resource_arns = var.ses_identity_arn
    #   }
    # } : {}
  )
  tags = var.tags
}

# Security group for EC2
module "sg" {
  source            = "../../modules/sg"
  App_Name          = var.APP_NAME
  Env_Type          = var.ENV
  Github_Actions_IP = var.Github_Actions_IP
  Jenkins_IP        = var.Jenkins_IP
  use_default_rules = var.sg_use_default_rules
  ingress_rules     = var.sg_ingress_rules
  egress_rules      = var.sg_egress_rules
}

# EC2 IAM Role using template-based policies
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

module "ec2_role" {
  source             = "../../modules/iam-role"
  role_name          = lower("${var.APP_NAME}-${var.ENV}-ec2-role")
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags

  policy_arns_map = module.app_role_policies.policy_arns_map
}

locals {
  startup_user_data = templatefile("${path.module}/startup_exact.sh", {
    JENKINS_SSH_PUBLIC_KEY        = var.jenkins_ssh_public_key
    GITHUB_ACTIONS_SSH_PUBLIC_KEY = var.github_actions_ssh_public_key
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = lower("${var.APP_NAME}-${var.ENV}-ec2-profile")
  role = module.ec2_role.role_name
  tags = var.tags
}

module "ec2_instance" {
  depends_on = [
    module.app_ecr,
    module.app_secrets,
    aws_iam_instance_profile.ec2,
    module.sg
  ]
  source = "../../modules/ec2"


  App_Name          = var.APP_NAME
  Env_Type          = var.ENV
  EC2_AMI_FILTER    = var.EC2_AMI_FILTER
  EC2_INSTANCE_TYPE = var.EC2_INSTANCE_TYPE
  EC2_PRIVATE_KEY   = var.EC2_PRIVATE_KEY
  EC2_AZ            = var.EC2_AZ
  EC2_SG_ID         = module.sg.sg_id_ec2
  IAM_PROFILE       = aws_iam_instance_profile.ec2.name

  #Optional Envs
  EC2_AMI               = var.EC2_AMI
  EC2_USER_DATA_CONTENT = local.startup_user_data
  EC2_ROOT_VOLUME_TYPE  = var.EC2_ROOT_VOLUME_TYPE
  EC2_ROOT_VOLUME_SIZE  = var.EC2_ROOT_VOLUME_SIZE
}

# Elastic IP for backend server
module "backend_eip" {
  source = "../../modules/eip"

  app_name    = var.APP_NAME
  env_type    = var.ENV
  instance_id = module.ec2_instance.instance_id
  tags        = var.tags

  depends_on = [module.ec2_instance]
}
