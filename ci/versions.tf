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
  region              = "eu-central-1"   # IAM is global; the plan bucket is regional and lives here
  allowed_account_ids = [var.account_id] # org-tf roles live in the management account
  default_tags {
    tags = { project = "sketch", stack = "ci", managed-by = "terraform" }
  }
}

# CI hub: reached from the management account through the role Organizations created in the member account
provider "aws" {
  alias               = "admin"
  region              = "eu-central-1" # IAM is global: region only selects the API endpoint
  allowed_account_ids = [var.admin_account_id]
  assume_role {
    role_arn = "arn:aws:iam::${var.admin_account_id}:role/OrganizationAccountAccessRole"
  }
  default_tags {
    tags = { project = "sketch", stack = "ci", managed-by = "terraform" }
  }
}

# Workload account: kantor-infra CI roles and the permissions boundary of its stack
provider "aws" {
  alias               = "dev"
  region              = "eu-central-1"
  allowed_account_ids = [var.dev_account_id]
  assume_role {
    role_arn = "arn:aws:iam::${var.dev_account_id}:role/OrganizationAccountAccessRole"
  }
  default_tags {
    tags = { project = "sketch", stack = "ci", managed-by = "terraform" }
  }
}
