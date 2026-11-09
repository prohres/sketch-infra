locals {
  permission_sets = {
    AdministratorAccess = {
      description = "Full access"
      policy_arn  = "arn:aws:iam::aws:policy/AdministratorAccess"
      session     = "PT4H"
    }
    PowerUserAccess = {
      description = "Full access except IAM and Organizations"
      policy_arn  = "arn:aws:iam::aws:policy/PowerUserAccess"
      session     = "PT4H"
    }
    ReadOnlyAccess = {
      description = "Read-only access"
      policy_arn  = "arn:aws:iam::aws:policy/ReadOnlyAccess"
      session     = "PT8H"
    }
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each         = local.permission_sets
  instance_arn     = local.instance_arn
  name             = each.key
  description      = each.value.description
  session_duration = each.value.session
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each           = local.permission_sets
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  managed_policy_arn = each.value.policy_arn
}
