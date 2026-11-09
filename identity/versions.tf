terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }

  backend "s3" {
    bucket       = "sketch-tfstate-183691668268"
    key          = "identity/terraform.tfstate"
    region       = "eu-central-1"
    profile      = "sketch-root"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region              = "eu-central-1" # Identity Center home region
  profile             = "sketch-root"
  allowed_account_ids = ["183691668268"] # Identity Center is administered from the management account
  default_tags {
    tags = { project = "sketch", stack = "identity", managed-by = "terraform" }
  }
}
