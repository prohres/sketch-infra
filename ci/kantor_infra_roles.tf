# CI roles for kantor-infra. They live here, not in kantor-infra: that stack is destroyed between
# sessions and must not delete the roles it runs as. The whole stack is in sketch-dev, so CI chains
# straight into one role there; state and saved plans stay in the management account's buckets.
locals {
  kantor_infra_sub    = "repo:prohres@38884861/kantor-infra@175958451" # immutable subject, as for sketch-infra
  kantor_prefix       = "kantor-infra"                                 # state key prefix and plan prefix
  kantor_stack_roles  = [for name in ["kantor-dev-execution", "app-deploy"] : "arn:aws:iam::${var.dev_account_id}:role/${name}"]
  kantor_execution    = local.kantor_stack_roles[0]
  kantor_boundary_arn = "arn:aws:iam::${var.dev_account_id}:policy/kantor-stack-boundary"

  kantor_tf_roles = {
    "kantor-tf-plan"  = { caller = "gha-kantor-plan", managed = "ReadOnlyAccess" }
    "kantor-tf-apply" = { caller = "gha-kantor-apply", managed = "PowerUserAccess" } # no IAM: granted below, stack roles only
  }
}

data "aws_iam_policy_document" "kantor_tf_trust" {
  for_each = local.kantor_tf_roles
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.admin_account_id}:role/${each.value.caller}"] # one role, not the account
    }
  }
}

resource "aws_iam_role" "kantor_tf" {
  provider           = aws.dev
  for_each           = local.kantor_tf_roles
  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.kantor_tf_trust[each.key].json
  depends_on         = [aws_iam_role.gha] # the trusted principal must exist
}

resource "aws_iam_role_policy_attachment" "kantor_tf" {
  provider   = aws.dev
  for_each   = local.kantor_tf_roles
  role       = aws_iam_role.kantor_tf[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/${each.value.managed}"
}

# Own state key and saved plans across accounts (the buckets grant the same in their policies)
data "aws_iam_policy_document" "kantor_tf_state" {
  for_each = local.kantor_tf_roles
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
  }
  statement {
    actions   = each.key == "kantor-tf-apply" ? ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"] : ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/${local.kantor_prefix}/*"]
  }
  dynamic "statement" {
    for_each = each.key == "kantor-tf-plan" ? [1] : []
    content {
      actions   = ["s3:PutObject", "s3:DeleteObject"] # plan only takes the lock
      resources = ["arn:aws:s3:::${local.state_bucket}/${local.kantor_prefix}/*.tflock"]
    }
  }
  statement {
    actions   = [each.key == "kantor-tf-apply" ? "s3:GetObject" : "s3:PutObject"] # plan writes, apply reads it back
    resources = ["arn:aws:s3:::${local.plan_bucket}/${local.kantor_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "kantor_tf_state" {
  provider = aws.dev
  for_each = local.kantor_tf_roles
  name     = "tf-state"
  role     = aws_iam_role.kantor_tf[each.key].id
  policy   = data.aws_iam_policy_document.kantor_tf_state[each.key].json
}

# IAM for the apply role: only the two roles the stack creates, and only with the boundary on them.
# Not granted at all: other roles, removing the boundary, changing the boundary policy.
data "aws_iam_policy_document" "kantor_tf_iam" {
  statement {
    sid = "StackRolesOnlyWithTheBoundary"
    actions = ["iam:CreateRole", "iam:PutRolePermissionsBoundary", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
    "iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = local.kantor_stack_roles
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.kantor_boundary_arn]
    }
  }
  statement {
    sid = "StackRolesLifecycle"
    actions = ["iam:GetRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy", "iam:TagRole",
      "iam:UntagRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
    "iam:ListInstanceProfilesForRole"]
    resources = local.kantor_stack_roles
  }
  statement {
    sid       = "PassOnlyTheExecutionRole"
    actions   = ["iam:PassRole"]
    resources = [local.kantor_execution]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "kantor_tf_iam" {
  provider = aws.dev
  name     = "stack-roles"
  role     = aws_iam_role.kantor_tf["kantor-tf-apply"].id
  policy   = data.aws_iam_policy_document.kantor_tf_iam.json
}

# Ceiling for the stack's roles: whatever policy CI writes on them, they can do no more than this
data "aws_iam_policy_document" "kantor_stack_boundary" {
  statement {
    sid = "NoResourceScoping"
    actions = ["ecr:GetAuthorizationToken", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition",
    "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:DescribeLoadBalancers"]
    resources = ["*"]
  }
  statement {
    sid       = "PullTheAppImage"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
    resources = ["arn:aws:ecr:eu-central-1:${var.dev_account_id}:repository/kantor"]
  }
  statement {
    sid       = "WriteAppLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:eu-central-1:${var.dev_account_id}:log-group:/ecs/kantor-dev:*"]
  }
  statement {
    sid       = "RollOutTheAppService"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = ["arn:aws:ecs:eu-central-1:${var.dev_account_id}:service/kantor-dev/*"]
  }
  statement {
    sid       = "PassOnlyTheExecutionRole"
    actions   = ["iam:PassRole"]
    resources = [local.kantor_execution]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "kantor_stack_boundary" {
  provider    = aws.dev
  name        = "kantor-stack-boundary"
  description = "Permissions boundary for the IAM roles of the kantor-infra stack"
  policy      = data.aws_iam_policy_document.kantor_stack_boundary.json
}
