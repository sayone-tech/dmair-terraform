resource "aws_s3_bucket" "website_s3" {
  bucket = lower("${var.APP_NAME}-${var.ENV}")
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.website_s3.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.website_s3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "website_s3_public_access" {
  bucket = aws_s3_bucket.website_s3.id

  block_public_acls       = var.AWS_S3_block_public_acls
  block_public_policy     = var.AWS_S3_block_public_policy
  ignore_public_acls      = var.AWS_S3_ignore_public_acls
  restrict_public_buckets = var.AWS_S3_restrict_public_buckets
}

resource "aws_s3_bucket_cors_configuration" "website_s3_cors" {
  bucket = aws_s3_bucket.website_s3.id

  cors_rule {
    allowed_headers = var.S3_cors_Allowed_Headers
    allowed_methods = var.S3_cors_Allowed_Methods
    allowed_origins = var.S3_cors_Allowed_Origins
    expose_headers  = var.S3_cors_Expose_Headers
    max_age_seconds = var.S3_cors_Max_Age
  }
}

# Website configuration (conditional)
resource "aws_s3_bucket_website_configuration" "website_s3_website" {
  count  = var.enable_website ? 1 : 0
  bucket = aws_s3_bucket.website_s3.id

  index_document {
    suffix = var.WEBSITE_index_file
  }

  error_document {
    key = var.WEBSITE_error_file
  }
}
