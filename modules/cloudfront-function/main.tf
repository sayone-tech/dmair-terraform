resource "aws_cloudfront_function" "this" {
  name    = "${var.app_name}-${var.env}-${var.function_name}"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = templatefile("${path.module}/${var.function_file}", var.function_vars)
}

