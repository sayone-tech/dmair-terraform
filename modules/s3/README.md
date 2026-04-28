<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.website_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.website_s3_cors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_public_access_block.website_s3_public_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.sse](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_website_configuration.website_s3_website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_APP_NAME"></a> [APP\_NAME](#input\_APP\_NAME) | Application name | `string` | n/a | yes |
| <a name="input_AWS_S3_Bucket_ACL_TYPE"></a> [AWS\_S3\_Bucket\_ACL\_TYPE](#input\_AWS\_S3\_Bucket\_ACL\_TYPE) | S3 bucket ACL type | `string` | `"private"` | no |
| <a name="input_AWS_S3_block_public_acls"></a> [AWS\_S3\_block\_public\_acls](#input\_AWS\_S3\_block\_public\_acls) | Block public ACLs | `bool` | `true` | no |
| <a name="input_AWS_S3_block_public_policy"></a> [AWS\_S3\_block\_public\_policy](#input\_AWS\_S3\_block\_public\_policy) | Block public policy | `bool` | `true` | no |
| <a name="input_AWS_S3_ignore_public_acls"></a> [AWS\_S3\_ignore\_public\_acls](#input\_AWS\_S3\_ignore\_public\_acls) | Ignore public ACLs | `bool` | `true` | no |
| <a name="input_AWS_S3_restrict_public_buckets"></a> [AWS\_S3\_restrict\_public\_buckets](#input\_AWS\_S3\_restrict\_public\_buckets) | Restrict public buckets | `bool` | `true` | no |
| <a name="input_ENV"></a> [ENV](#input\_ENV) | Environment | `string` | n/a | yes |
| <a name="input_S3_cors_Allowed_Headers"></a> [S3\_cors\_Allowed\_Headers](#input\_S3\_cors\_Allowed\_Headers) | S3 CORS allowed headers | `list(string)` | <pre>[<br/>  "*"<br/>]</pre> | no |
| <a name="input_S3_cors_Allowed_Methods"></a> [S3\_cors\_Allowed\_Methods](#input\_S3\_cors\_Allowed\_Methods) | S3 CORS allowed methods | `list(string)` | <pre>[<br/>  "GET"<br/>]</pre> | no |
| <a name="input_S3_cors_Allowed_Origins"></a> [S3\_cors\_Allowed\_Origins](#input\_S3\_cors\_Allowed\_Origins) | S3 CORS allowed origins | `list(string)` | <pre>[<br/>  "*"<br/>]</pre> | no |
| <a name="input_S3_cors_Expose_Headers"></a> [S3\_cors\_Expose\_Headers](#input\_S3\_cors\_Expose\_Headers) | S3 CORS expose headers | `list(string)` | <pre>[<br/>  "ETag"<br/>]</pre> | no |
| <a name="input_S3_cors_Max_Age"></a> [S3\_cors\_Max\_Age](#input\_S3\_cors\_Max\_Age) | S3 CORS max age in seconds | `number` | `3000` | no |
| <a name="input_WEBSITE_error_file"></a> [WEBSITE\_error\_file](#input\_WEBSITE\_error\_file) | Default error file for website | `string` | `"error.html"` | no |
| <a name="input_WEBSITE_index_file"></a> [WEBSITE\_index\_file](#input\_WEBSITE\_index\_file) | Default index file for website | `string` | `"index.html"` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Enable S3 server-side encryption | `bool` | `true` | no |
| <a name="input_enable_versioning"></a> [enable\_versioning](#input\_enable\_versioning) | Enable S3 bucket versioning | `bool` | `false` | no |
| <a name="input_enable_website"></a> [enable\_website](#input\_enable\_website) | Enable S3 website hosting | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_S3-Bucket-ARN"></a> [S3-Bucket-ARN](#output\_S3-Bucket-ARN) | S3 bucket ARN |
| <a name="output_S3-Bucket-Domain"></a> [S3-Bucket-Domain](#output\_S3-Bucket-Domain) | S3 bucket domain name |
| <a name="output_S3-Bucket-NAME"></a> [S3-Bucket-NAME](#output\_S3-Bucket-NAME) | S3 bucket name |
| <a name="output_S3-Website-Endpoint"></a> [S3-Website-Endpoint](#output\_S3-Website-Endpoint) | S3 website endpoint |
<!-- END_TF_DOCS -->