terraform {
  backend "s3" {
    bucket     = "ruuvi-aws-terraform-state"
    key        = "state.tfstate"
    region     = "eu-central-1"
  }
}
