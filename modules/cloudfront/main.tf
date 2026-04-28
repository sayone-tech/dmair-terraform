data "aws_iam_policy_document" "s3-policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${var.s3_arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn_distribution.arn]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "wesite_access_control" {
  name                              = var.s3_regional_domain
  description                       = "website access control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "no-override"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn_distribution" {
  origin {
    domain_name              = var.s3_regional_domain
    origin_access_control_id = aws_cloudfront_origin_access_control.wesite_access_control.id
    origin_id                = var.S3_Origin_ID
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.CDN_Describtion
  default_root_object = var.CDN_Default_Root

  # Aliases (custom domains)
  aliases = var.domain != "" ? split(",", var.domain) : []

  default_cache_behavior {
    allowed_methods  = var.CDN_Allowed_Methods != null ? var.CDN_Allowed_Methods : ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = var.CDN_Cached_Methods != null ? var.CDN_Cached_Methods : ["GET", "HEAD"]
    target_origin_id = var.S3_Origin_ID

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    # Attach CloudFront Function (e.g., for basic auth)
    dynamic "function_association" {
      for_each = var.viewer_request_function_arn != "" ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = var.viewer_request_function_arn
      }
    }
  }


  # Custom error response for SPA (matching existing configuration)
  dynamic "custom_error_response" {
    for_each = var.CDN_Custom_Error_Response != null ? [1] : []
    content {
      error_code            = 404
      response_code         = 200
      response_page_path    = var.CDN_Custom_Error_Response
      error_caching_min_ttl = 600
    }
  }

  dynamic "custom_error_response" {
    for_each = var.CDN_Custom_Error_Response != null ? [1] : []
    content {
      error_code            = 403
      response_code         = 200
      response_page_path    = var.CDN_Custom_Error_Response
      error_caching_min_ttl = 600
    }
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Use ACM certificate when provided
  dynamic "viewer_certificate" {
    for_each = var.acm_certificate != "" ? [1] : []
    content {
      acm_certificate_arn = var.acm_certificate
      ssl_support_method  = "sni-only"
    }
  }

  # Use CloudFront default certificate when no ACM certificate is provided
  dynamic "viewer_certificate" {
    for_each = var.acm_certificate == "" ? [1] : []
    content {
      cloudfront_default_certificate = true
    }
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "cdn-s3-policy" {
  bucket = var.s3_name
  policy = data.aws_iam_policy_document.s3-policy.json
}
