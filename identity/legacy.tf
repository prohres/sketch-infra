# Legacy direct user assignments created manually on 2026-11-07.
# Imported only so that the next commit can destroy them; access now comes from groups.
locals {
  legacy_user_assignments = toset(["sketch-root", "sketch-admin"])
}

resource "aws_ssoadmin_account_assignment" "legacy_user" {
  for_each           = local.legacy_user_assignments
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this["AdministratorAccess"].arn
  principal_type     = "USER"
  principal_id       = data.aws_identitystore_user.me.user_id
  target_type        = "AWS_ACCOUNT"
  target_id          = local.account_ids[each.key]
}

import {
  for_each = local.legacy_user_assignments
  to       = aws_ssoadmin_account_assignment.legacy_user[each.key]
  # principal_id,principal_type,target_id,target_type,permission_set_arn,instance_arn
  id = join(",", [
    data.aws_identitystore_user.me.user_id, "USER",
    local.account_ids[each.key], "AWS_ACCOUNT",
    aws_ssoadmin_permission_set.this["AdministratorAccess"].arn, local.instance_arn,
  ])
}
