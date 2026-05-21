terraform {
  backend "s3" {
    bucket                   = "dmair-terraform-prod"
    key                      = "staging/backend/terraform.tfstate"
    region                   = "us-west-2" # us-west-2
    profile                  = "dmair"
    shared_credentials_files = ["~/.aws/credentials"]
    use_lockfile             = true
  }
}
