APP_NAME    = "dmair-frontend"
ENV         = "staging"
aws_region  = "us-west-2"
aws_profile = "dmair"

domain            = "staging.dmair.net"
website_s3_bucket = "staging.dmair.net"
tags = {
  Env = "staging"
}
S3_cors_Allowed_Methods = ["GET", "POST", "PUT"]
S3_cors_Allowed_Origins = ["*.dmair.net"]

S3_Origin_ID              = "staging.dmair.net"
CDN_Allowed_Methods       = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
CDN_Cached_Methods        = ["GET", "HEAD"]
CDN_Custom_Error_Response = "/404.html"
acm_certificate           = "arn:aws:acm:us-east-1:071297531943:certificate/88755027-a98c-4ef0-b63b-7507303d55d1" # ACM certificate ARN (must be in us-east-1)


# Basic Auth Configuration for CloudFront
# Set enable_basic_auth = true to enable basic authentication
# basic_auth_credentials should be base64 encoded (username:password)
# Example: echo -n "sayoneadmin:ASDF@#1234" | base64
enable_basic_auth      = true
basic_auth_credentials = "c2F5b25lYWRtaW46QVNERkAjMTIzNA=="
