# GitHub Actions identity in the CI hub (sketch-admin). These roles can do nothing
# except assume their one counterpart in the management account.
resource "aws_iam_openid_connect_provider" "github" {
  provider       = aws.admin
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  gha_roles = {
    "gha-plan" = {
      # PR plans and the scheduled drift check on develop
      subjects = ["${local.repo_sub}:pull_request", "${local.repo_sub}:ref:refs/heads/develop"]
      target   = local.org_role_arns["org-tf-plan"]
    }
    "gha-apply" = {
      # Only jobs that passed the prod environment approval
      subjects = ["${local.repo_sub}:environment:prod"]
      target   = local.org_role_arns["org-tf-apply"]
    }
  }
}

data "aws_iam_policy_document" "gha_trust" {
  for_each = local.gha_roles
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
      test     = "StringEquals" # exact subjects, never a wildcard (any branch could skip the approval)
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value.subjects
    }
  }
}

resource "aws_iam_role" "gha" {
  provider           = aws.admin
  for_each           = local.gha_roles
  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.gha_trust[each.key].json
}

data "aws_iam_policy_document" "gha_chain" {
  for_each = local.gha_roles
  statement {
    actions   = ["sts:AssumeRole", "sts:TagSession"] # configure-aws-credentials tags chained sessions
    resources = [each.value.target]
  }
}

resource "aws_iam_role_policy" "gha_chain" {
  provider = aws.admin
  for_each = local.gha_roles
  name     = "assume-org-role"
  role     = aws_iam_role.gha[each.key].id
  policy   = data.aws_iam_policy_document.gha_chain[each.key].json
}
