terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }

  backend "s3" {
    key = "ci/terraform.tfstate" # shared settings: ../backend.hcl
  }
}

provider "aws" {
  region              = "eu-central-1"   # IAM is global: region only selects the API endpoint
  allowed_account_ids = ["183691668268"] # org-tf roles live in the management account
  default_tags {
    tags = { project = "sketch", stack = "ci", managed-by = "terraform" }
  }
}

# CI hub: reached from the management account through the role Organizations created in the member account
provider "aws" {
  alias               = "admin"
  region              = "eu-central-1" # IAM is global: region only selects the API endpoint
  allowed_account_ids = ["686337362279"]
  assume_role {
    role_arn = "arn:aws:iam::686337362279:role/OrganizationAccountAccessRole"
  }
  default_tags {
    tags = { project = "sketch", stack = "ci", managed-by = "terraform" }
  }
}
