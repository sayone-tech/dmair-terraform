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
| [aws_security_group.sg_ec2_defaults](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_App_Name"></a> [App\_Name](#input\_App\_Name) | Application name | `string` | n/a | yes |
| <a name="input_Env_Type"></a> [Env\_Type](#input\_Env\_Type) | Environment type | `string` | n/a | yes |
| <a name="input_Sayone_Jenkins"></a> [Sayone\_Jenkins](#input\_Sayone\_Jenkins) | Jenkins IP CIDR | `string` | `"34.136.212.252/32"` | no |
| <a name="input_egress_rules"></a> [egress\_rules](#input\_egress\_rules) | Custom egress rules | <pre>list(object({<br/>    from_port        = number<br/>    to_port          = number<br/>    protocol         = string<br/>    cidr_blocks      = list(string)<br/>    ipv6_cidr_blocks = list(string)<br/>    security_groups  = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | Custom ingress rules | <pre>list(object({<br/>    description      = string<br/>    from_port        = number<br/>    to_port          = number<br/>    protocol         = string<br/>    cidr_blocks      = list(string)<br/>    ipv6_cidr_blocks = list(string)<br/>    security_groups  = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_use_default_rules"></a> [use\_default\_rules](#input\_use\_default\_rules) | Whether to use default HTTP/HTTPS/SSH rules | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_sg_arn"></a> [sg\_arn](#output\_sg\_arn) | Security group ARN |
| <a name="output_sg_id_ec2"></a> [sg\_id\_ec2](#output\_sg\_id\_ec2) | Security group ID |
<!-- END_TF_DOCS -->