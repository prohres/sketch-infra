# Roles in the management account that Terraform runs as in CI. Each trusts exactly one gha role,
# and none of the attached policies grants sts:AssumeRole, so CI cannot hop into member accounts from here.
locals {
  org_roles = {
    "org-tf-plan" = {
      caller  = "gha-plan"
      managed = ["ReadOnlyAccess"]
    }
    "org-tf-apply" = {
      caller  = "gha-apply"
      managed = ["ReadOnlyAccess", "AWSOrganizationsFullAccess", "AWSSSOMasterAccountAdministrator"]
    }
  }

  org_role_attachments = merge([
    for role, cfg in local.org_roles : { for policy in cfg.managed : "${role}/${policy}" => { role = role, policy = policy } }
  ]...)
}

data "aws_iam_policy_document" "org_trust" {
  for_each = local.org_roles
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.gha[each.value.caller].arn] # one role, not the whole account
    }
  }
}

resource "aws_iam_role" "org" {
  for_each           = local.org_roles
  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.org_trust[each.key].json
}

resource "aws_iam_role_policy_attachment" "org" {
  for_each   = local.org_role_attachments
  role       = aws_iam_role.org[each.value.role].name
  policy_arn = "arn:aws:iam::aws:policy/${each.value.policy}"
}

# Plan only takes the S3 lock; ReadOnlyAccess already covers reading the state
data "aws_iam_policy_document" "state_plan" {
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = [for stack in local.ci_stacks : "arn:aws:s3:::${local.state_bucket}/${stack}/*.tflock"]
  }
}

data "aws_iam_policy_document" "state_apply" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [for stack in local.ci_stacks : "arn:aws:s3:::${local.state_bucket}/${stack}/*"]
  }
}

resource "aws_iam_role_policy" "org_state" {
  for_each = {
    "org-tf-plan"  = data.aws_iam_policy_document.state_plan.json
    "org-tf-apply" = data.aws_iam_policy_document.state_apply.json
  }
  name   = "tf-state"
  role   = aws_iam_role.org[each.key].id
  policy = each.value
}
