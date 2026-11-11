terraform {
  required_version = ">= 1.10" # S3 backend use_lockfile requires 1.10+
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region              = "eu-central-1"
  allowed_account_ids = [var.account_id] # guardrail: management account only
  default_tags {
    tags = { project = "sketch", stack = "bootstrap", managed-by = "terraform" }
  }
}

resource "aws_s3_bucket" "tfstate" {
  #checkov:skip=CKV_AWS_18:Access logs need a separate log bucket; revisit with a log-archive account
  #checkov:skip=CKV_AWS_145:SSE-S3 on purpose (no KMS cost); access is limited by IAM
  bucket = "sketch-tfstate-${var.account_id}" # account id suffix keeps the name globally unique
  lifecycle { prevent_destroy = true }        # protect all stacks' state from accidental destroy
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
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

# kantor-infra runs in sketch-dev: its two CI roles reach their own state key across accounts, nothing else
locals {
  kantor_tf = { for r in ["kantor-tf-plan", "kantor-tf-apply"] : r => "arn:aws:iam::${var.dev_account_id}:role/${r}" }
}

data "aws_iam_policy_document" "tfstate" {
  statement {
    sid       = "KantorInfraList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
    principals {
      type        = "AWS"
      identifiers = values(local.kantor_tf)
    }
  }
  statement {
    sid       = "KantorInfraRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/kantor-infra/*"]
    principals {
      type        = "AWS"
      identifiers = values(local.kantor_tf)
    }
  }
  statement {
    sid       = "KantorInfraPlanLock"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/kantor-infra/*.tflock"]
    principals {
      type        = "AWS"
      identifiers = [local.kantor_tf["kantor-tf-plan"]]
    }
  }
  statement {
    sid       = "KantorInfraApplyWrite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/kantor-infra/*"]
    principals {
      type        = "AWS"
      identifiers = [local.kantor_tf["kantor-tf-apply"]]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate.json
}

output "state_bucket" { value = aws_s3_bucket.tfstate.bucket }
