APP_NAME    = "dmair-frontend"
ENV         = "prod"
aws_region  = "us-west-2"
aws_profile = "dmair"

domain            = "www.flydmair.com"
website_s3_bucket = "www.dmair.net"
tags = {
  Env = "prod"
}
S3_cors_Allowed_Methods = ["GET", "POST", "PUT"]
S3_cors_Allowed_Origins = ["*.flydmair.com"]

S3_Origin_ID              = "www.dmair.net"
CDN_Allowed_Methods       = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
CDN_Cached_Methods        = ["GET", "HEAD"]
CDN_Custom_Error_Response = "/404.html"
acm_certificate           = "arn:aws:acm:us-east-1:071297531943:certificate/73552aef-38f3-433d-8273-d4e838bfb244" # ACM certificate ARN (must be in us-east-1)
