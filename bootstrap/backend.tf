terraform {
  backend "s3" {
    key = "bootstrap/terraform.tfstate" # shared settings: ../backend.hcl
  }
}
