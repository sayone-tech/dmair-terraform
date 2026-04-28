# Elastic IP (EIP) Module

This module creates an AWS Elastic IP and optionally associates it with an EC2 instance.

## Features

- Creates an Elastic IP in VPC domain
- Automatic association with EC2 instance
- Configurable lifecycle management
- Comprehensive tagging support
- Optional explicit association control

## Usage

```hcl
module "backend_eip" {
  source = "../../modules/eip"

  app_name    = "my-app"
  env_type    = "staging"
  instance_id = module.ec2_instance.instance_id

  tags = {
    Environment = "staging"
    Project     = "my-project"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Resources

| Name | Type |
|------|------|
| [aws_eip.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| app_name | Application name for resource naming | `string` | n/a | yes |
| env_type | Environment type (e.g., dev, staging, prod) | `string` | n/a | yes |
| instance_id | EC2 instance ID to associate with the Elastic IP | `string` | n/a | yes |
| tags | A mapping of tags to assign to the Elastic IP | `map(string)` | `{}` | no |
| associate_with_instance | Whether to explicitly associate the EIP with the instance | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| eip_id | The allocation ID of the Elastic IP |
| eip_public_ip | The public IP address of the Elastic IP |
| eip_public_dns | The public DNS name of the Elastic IP |
| eip_private_ip | The private IP address associated with the Elastic IP |
| eip_private_dns | The private DNS name associated with the Elastic IP |
| eip_association_id | The association ID of the Elastic IP |

## Notes

- The Elastic IP is created in VPC domain by default
- The `prevent_destroy` lifecycle rule is enabled by default to prevent accidental deletion
- The EIP is automatically associated with the instance when `instance_id` is provided
- Use `associate_with_instance = true` only if you need explicit control over the association
