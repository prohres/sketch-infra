terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }

  backend "s3" {
    key = "org/terraform.tfstate" # shared settings: ../backend.hcl
  }
}

provider "aws" {
  region              = "eu-central-1"   # Organizations is global: region only selects the API endpoint
  allowed_account_ids = ["183691668268"] # Organizations API is available in the management account only
  default_tags {
    tags = { project = "sketch", stack = "org", managed-by = "terraform", repo = "prohres/sketch-infra" }
  }
}
