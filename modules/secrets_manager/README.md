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
| [aws_secretsmanager_secret.secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_App_Name"></a> [App\_Name](#input\_App\_Name) | Application name | `string` | n/a | yes |
| <a name="input_Env_Type"></a> [Env\_Type](#input\_Env\_Type) | Environment type | `string` | n/a | yes |
| <a name="input_recovery_window_in_days"></a> [recovery\_window\_in\_days](#input\_recovery\_window\_in\_days) | Recovery window in days | `number` | `7` | no |
| <a name="input_secret_string"></a> [secret\_string](#input\_secret\_string) | Secret string value | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_secretsmanager_arn"></a> [secretsmanager\_arn](#output\_secretsmanager\_arn) | Secrets Manager secret ARN |
| <a name="output_secretsmanager_name"></a> [secretsmanager\_name](#output\_secretsmanager\_name) | Secrets Manager secret name |
<!-- END_TF_DOCS -->