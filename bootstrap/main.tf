terraform {
  required_version = ">= 1.10" # S3 backend use_lockfile requires 1.10+
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region              = "eu-central-1"
  allowed_account_ids = ["183691668268"] # guardrail: management account only
  default_tags {
    tags = { project = "sketch", stack = "bootstrap", managed-by = "terraform" }
  }
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "sketch-tfstate-183691668268" # account id suffix keeps the name globally unique
  lifecycle { prevent_destroy = true }   # protect all stacks' state from accidental destroy
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" } # allows rollback of a corrupted state
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" } # SSE-S3, no KMS cost
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 } # don't keep old versions forever
  }
}

output "state_bucket" { value = aws_s3_bucket.tfstate.bucket }
