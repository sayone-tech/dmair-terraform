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
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for managed policy names | `string` | n/a | yes |
| <a name="input_policy_templates"></a> [policy\_templates](#input\_policy\_templates) | List of policy template names (without .tpl extension) | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to IAM resources | `map(string)` | `{}` | no |
| <a name="input_template_vars"></a> [template\_vars](#input\_template\_vars) | Map of variables per template name for templatefile rendering | `map(any)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_policy_arns"></a> [policy\_arns](#output\_policy\_arns) | List of managed policy ARNs created |
| <a name="output_policy_arns_map"></a> [policy\_arns\_map](#output\_policy\_arns\_map) | Map of template name to managed policy ARN |
<!-- END_TF_DOCS -->