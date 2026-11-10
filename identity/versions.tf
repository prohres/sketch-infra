terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }

  backend "s3" {
    key = "identity/terraform.tfstate" # shared settings: ../backend.hcl
  }
}

provider "aws" {
  region              = "eu-central-1"   # Identity Center home region
  allowed_account_ids = ["183691668268"] # Identity Center is administered from the management account
  default_tags {
    tags = { project = "sketch", stack = "identity", managed-by = "terraform", repo = "prohres/sketch-infra" }
  }
}
