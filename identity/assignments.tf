locals {
  # Who gets what where: group => { account name => permission set }.
  # Humans are read-only in prod; changes there go through CI/CD only.
  access_matrix = {
    OrgAdmins = {
      "sketch-root" = "AdministratorAccess"
    }
    PlatformAdmins = {
      "sketch-root"  = "ReadOnlyAccess"
      "sketch-admin" = "AdministratorAccess"
      "sketch-dev"   = "AdministratorAccess"
    }
    Developers = {
      "sketch-dev"  = "PowerUserAccess"
      "sketch-prod" = "ReadOnlyAccess"
    }
    Auditors = {
      "sketch-root"  = "ReadOnlyAccess"
      "sketch-admin" = "ReadOnlyAccess"
      "sketch-dev"   = "ReadOnlyAccess"
      "sketch-prod"  = "ReadOnlyAccess"
    }
  }

  # Flatten to "Group/account" => { group, account, permission_set }
  assignments = merge([
    for group, accounts in local.access_matrix : {
      for account, permission_set in accounts : "${group}/${account}" => {
        group          = group
        account        = account
        permission_set = permission_set
      }
    }
  ]...)
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each           = local.assignments
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.this[each.value.group].group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = local.account_ids[each.value.account]

  # Provision permission sets only once their policies are attached
  depends_on = [aws_ssoadmin_managed_policy_attachment.this]
}
