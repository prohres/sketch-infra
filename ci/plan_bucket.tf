# Saved plans for the apply pipeline. A plan file holds values in clear text (sensitive ones too),
# and GitHub artifacts of a public repo are downloadable by anyone, so plans stay in a private bucket.
locals {
  plan_bucket = "sketch-tfplans-${local.root_account_id}"
  plan_prefix = "sketch-infra" # <prefix>/<run_id>/<stack>.tfplan
}

resource "aws_s3_bucket" "plans" {
  bucket        = local.plan_bucket
  force_destroy = true # transient data only, unlike the state bucket
}

resource "aws_s3_bucket_server_side_encryption_configuration" "plans" {
  bucket = aws_s3_bucket.plans.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "plans" {
  bucket                  = aws_s3_bucket.plans.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "plans" {
  bucket = aws_s3_bucket.plans.id
  rule {
    id     = "expire-plans"
    status = "Enabled"
    filter {}
    expiration { days = 7 } # a plan older than a week is stale anyway
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

data "aws_iam_policy_document" "plans_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.plans.arn, "${aws_s3_bucket.plans.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "plans" {
  bucket = aws_s3_bucket.plans.id
  policy = data.aws_iam_policy_document.plans_tls_only.json
}

# Plan role writes the saved plan, apply role reads exactly that file back
resource "aws_iam_role_policy" "org_plans" {
  for_each = {
    "org-tf-plan"  = "s3:PutObject"
    "org-tf-apply" = "s3:GetObject"
  }
  name = "tf-plans"
  role = aws_iam_role.org[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = each.value
      Resource = "${aws_s3_bucket.plans.arn}/${local.plan_prefix}/*"
    }]
  })
}
