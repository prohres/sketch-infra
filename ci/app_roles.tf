# CI roles for the kantor app repo (sketch-admin). Build touches only the ECR repo in this account;
# deploy chains into one role in the workload account.
locals {
  app_repo_sub   = "repo:prohres@38884861/kantor@132234591" # immutable subject, as for sketch-infra
  dev_account_id = var.dev_account_id
  # Created by kantor-infra; moving from sketch-admin to sketch-dev: drop the admin ARN after the move
  app_ecr_arns = [
    "arn:aws:ecr:eu-central-1:${var.admin_account_id}:repository/kantor",
    "arn:aws:ecr:eu-central-1:${var.dev_account_id}:repository/kantor",
  ]

  app_roles = {
    "gha-app-build"      = ["${local.app_repo_sub}:ref:refs/heads/develop"] # push after merge; PRs get no AWS access
    "gha-app-deploy-dev" = ["${local.app_repo_sub}:environment:dev"]
  }
}

data "aws_iam_policy_document" "app_trust" {
  for_each = local.app_roles
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals" # exact subjects, never a wildcard
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value
    }
  }
}

resource "aws_iam_role" "app" {
  provider           = aws.admin
  for_each           = local.app_roles
  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.app_trust[each.key].json
}

data "aws_iam_policy_document" "app_permissions" {
  for_each = local.app_roles

  dynamic "statement" {
    for_each = each.key == "gha-app-build" ? [1] : []
    content {
      actions   = ["ecr:GetAuthorizationToken"] # registry login; can't be scoped to a repo
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "gha-app-build" ? [1] : []
    content {
      actions = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:DescribeImages", "ecr:DescribeRepositories"]
      resources = local.app_ecr_arns
    }
  }

  dynamic "statement" {
    for_each = each.key == "gha-app-deploy-dev" ? [1] : []
    content {
      actions   = ["sts:AssumeRole", "sts:TagSession"] # created by kantor-infra in sketch-dev
      resources = ["arn:aws:iam::${local.dev_account_id}:role/app-deploy"]
    }
  }
}

resource "aws_iam_role_policy" "app" {
  provider = aws.admin
  for_each = local.app_roles
  name     = "app-pipeline"
  role     = aws_iam_role.app[each.key].id
  policy   = data.aws_iam_policy_document.app_permissions[each.key].json
}
