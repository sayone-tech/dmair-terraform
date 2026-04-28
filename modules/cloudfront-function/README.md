# CloudFront Function Module

This module creates AWS CloudFront Functions that can be attached to CloudFront distributions to handle viewer requests and responses.

## Features

- Generic CloudFront function creation
- Template-based function code with variable interpolation
- Support for multiple function types (basic auth, custom headers, etc.)
- Automatic function publishing

## Usage

### Basic Authentication Function

```hcl
module "cloudfront_basic_auth" {
  source = "../../modules/cloudfront-function"

  app_name      = var.APP_NAME
  env           = var.ENV
  function_name = "basic-auth"
  function_file = "basic_auth.js"
  
  function_vars = {
    basic_auth_credentials = var.basic_auth_credentials
  }
  
  tags = var.tags
}
```

### Attaching to CloudFront Distribution

```hcl
resource "aws_cloudfront_distribution" "cdn_distribution" {
  # ... other configuration ...

  default_cache_behavior {
    # ... other configuration ...

    function_association {
      event_type   = "viewer-request"
      function_arn = module.cloudfront_basic_auth.function_arn
    }
  }
}
```

## Variables

- `app_name` - Application name
- `env` - Environment name
- `function_name` - Function name suffix
- `function_file` - Path to function file (relative to module)
- `function_vars` - Variables to pass to function template
- `tags` - Tags to apply to resources

## Outputs

- `function_arn` - ARN of the CloudFront function
- `function_name` - Name of the CloudFront function
- `function_etag` - ETag of the CloudFront function

## Function Files

### basic_auth.js

Implements HTTP Basic Authentication for CloudFront.

**Template Variables:**
- `basic_auth_credentials` - Base64 encoded credentials (format: base64(username:password))

**Example:**
```bash
echo -n "admin:password123" | base64
# YWRtaW46cGFzc3dvcmQxMjM=
```

## Event Types

- `viewer-request` - Triggered when CloudFront receives a request from a viewer
- `viewer-response` - Triggered before CloudFront returns a response to the viewer

## Limitations

- CloudFront Functions have a 10KB size limit
- Limited to JavaScript ES5 syntax
- No external API calls allowed
- Maximum execution time: 5 seconds

