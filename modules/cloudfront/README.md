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
| [aws_cloudfront_distribution.cdn_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_control.wesite_access_control](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_s3_bucket_policy.cdn-s3-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_iam_policy_document.s3-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_APP_NAME"></a> [APP\_NAME](#input\_APP\_NAME) | Application name | `string` | n/a | yes |
| <a name="input_CDN_Allowed_Methods"></a> [CDN\_Allowed\_Methods](#input\_CDN\_Allowed\_Methods) | Allowed methods | `list(string)` | `null` | no |
| <a name="input_CDN_Cached_Methods"></a> [CDN\_Cached\_Methods](#input\_CDN\_Cached\_Methods) | Cached methods | `list(string)` | `null` | no |
| <a name="input_CDN_Custom_Error_Response"></a> [CDN\_Custom\_Error\_Response](#input\_CDN\_Custom\_Error\_Response) | Custom error response page | `string` | `null` | no |
| <a name="input_CDN_Default_Root"></a> [CDN\_Default\_Root](#input\_CDN\_Default\_Root) | Default root object | `string` | `null` | no |
| <a name="input_CDN_Describtion"></a> [CDN\_Describtion](#input\_CDN\_Describtion) | CloudFront distribution description | `string` | `"CloudFront Distribution"` | no |
| <a name="input_ENV"></a> [ENV](#input\_ENV) | Environment | `string` | n/a | yes |
| <a name="input_S3_Origin_ID"></a> [S3\_Origin\_ID](#input\_S3\_Origin\_ID) | S3 origin ID | `string` | `"S3-Origin"` | no |
| <a name="input_acm_certificate"></a> [acm\_certificate](#input\_acm\_certificate) | ACM certificate ARN | `string` | `""` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | Custom domain name | `string` | `""` | no |
| <a name="input_s3_arn"></a> [s3\_arn](#input\_s3\_arn) | S3 bucket ARN | `string` | n/a | yes |
| <a name="input_s3_domain"></a> [s3\_domain](#input\_s3\_domain) | S3 bucket domain name | `string` | n/a | yes |
| <a name="input_s3_name"></a> [s3\_name](#input\_s3\_name) | S3 bucket name | `string` | n/a | yes |
| <a name="input_s3_regional_domain"></a> [s3\_regional\_domain](#input\_s3\_regional\_domain) | S3 bucket regional domain name | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cdn_distribution_arn"></a> [cdn\_distribution\_arn](#output\_cdn\_distribution\_arn) | CloudFront distribution ARN |
| <a name="output_cdn_distribution_domain_name"></a> [cdn\_distribution\_domain\_name](#output\_cdn\_distribution\_domain\_name) | CloudFront distribution domain name |
| <a name="output_cdn_distribution_id"></a> [cdn\_distribution\_id](#output\_cdn\_distribution\_id) | CloudFront distribution ID |
<!-- END_TF_DOCS -->