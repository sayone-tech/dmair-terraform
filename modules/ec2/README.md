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
| [aws_instance.app_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_ami.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_App_Name"></a> [App\_Name](#input\_App\_Name) | Application name | `string` | n/a | yes |
| <a name="input_EC2_AMI"></a> [EC2\_AMI](#input\_EC2\_AMI) | Specific AMI ID to use | `string` | `""` | no |
| <a name="input_EC2_AMI_FILTER"></a> [EC2\_AMI\_FILTER](#input\_EC2\_AMI\_FILTER) | AMI filter for automatic selection | `string` | `""` | no |
| <a name="input_EC2_AZ"></a> [EC2\_AZ](#input\_EC2\_AZ) | Availability zone | `string` | `""` | no |
| <a name="input_EC2_CPU_CREDITS"></a> [EC2\_CPU\_CREDITS](#input\_EC2\_CPU\_CREDITS) | CPU credits for burstable instances | `string` | `"standard"` | no |
| <a name="input_EC2_INSTANCE_TYPE"></a> [EC2\_INSTANCE\_TYPE](#input\_EC2\_INSTANCE\_TYPE) | EC2 instance type | `string` | `"t3.micro"` | no |
| <a name="input_EC2_PRIVATE_KEY"></a> [EC2\_PRIVATE\_KEY](#input\_EC2\_PRIVATE\_KEY) | EC2 key pair name | `string` | `""` | no |
| <a name="input_EC2_ROOT_VOLUME_SIZE"></a> [EC2\_ROOT\_VOLUME\_SIZE](#input\_EC2\_ROOT\_VOLUME\_SIZE) | Root volume size in GB | `number` | `20` | no |
| <a name="input_EC2_ROOT_VOLUME_TYPE"></a> [EC2\_ROOT\_VOLUME\_TYPE](#input\_EC2\_ROOT\_VOLUME\_TYPE) | Root volume type | `string` | `"gp3"` | no |
| <a name="input_EC2_SG_ID"></a> [EC2\_SG\_ID](#input\_EC2\_SG\_ID) | Security group ID | `string` | n/a | yes |
| <a name="input_EC2_USER_DATA_CONTENT"></a> [EC2\_USER\_DATA\_CONTENT](#input\_EC2\_USER\_DATA\_CONTENT) | User data script content | `string` | `""` | no |
| <a name="input_Env_Type"></a> [Env\_Type](#input\_Env\_Type) | Environment type | `string` | n/a | yes |
| <a name="input_IAM_PROFILE"></a> [IAM\_PROFILE](#input\_IAM\_PROFILE) | IAM instance profile name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_arn"></a> [instance\_arn](#output\_instance\_arn) | EC2 instance ARN |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | EC2 instance ID |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | EC2 instance private IP |
| <a name="output_public_dns"></a> [public\_dns](#output\_public\_dns) | EC2 instance public DNS |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | EC2 instance public IP |
<!-- END_TF_DOCS -->