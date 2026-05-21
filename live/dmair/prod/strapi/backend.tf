terraform {
  backend "s3" {
    bucket       = "dmair-terraform-prod"
    key          = "strapi/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
