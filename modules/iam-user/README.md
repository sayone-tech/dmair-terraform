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
| [aws_iam_access_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_user.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.attach_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Application name (kept for compatibility; not used) | `string` | `""` | no |
| <a name="input_create_access_key"></a> [create\_access\_key](#input\_create\_access\_key) | Whether to create an access key for the user | `bool` | `false` | no |
| <a name="input_env"></a> [env](#input\_env) | Environment (kept for compatibility; not used) | `string` | `""` | no |
| <a name="input_policy_arns_map"></a> [policy\_arns\_map](#input\_policy\_arns\_map) | Map of managed policy ARNs to attach to the user (keys should be static) | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to IAM resources | `map(string)` | `{}` | no |
| <a name="input_user_name"></a> [user\_name](#input\_user\_name) | IAM user name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_key_id"></a> [access\_key\_id](#output\_access\_key\_id) | Access key ID (if created) |
| <a name="output_secret_access_key"></a> [secret\_access\_key](#output\_secret\_access\_key) | Secret access key (if created) |
| <a name="output_user_arn"></a> [user\_arn](#output\_user\_arn) | IAM user ARN |
| <a name="output_user_name"></a> [user\_name](#output\_user\_name) | IAM user name |
<!-- END_TF_DOCS -->