locals {
  groups = {
    OrgAdmins      = "Admin on the management account"
    PlatformAdmins = "Admin on platform and non-prod accounts, read-only on management"
    Developers     = "PowerUser on non-prod, read-only on prod"
    Auditors       = "Read-only on every account"
  }
}

resource "aws_identitystore_group" "this" {
  for_each          = local.groups
  identity_store_id = local.identity_store_id
  display_name      = each.key
  description       = each.value
}

# People are provisioned outside Terraform (in a company: IdP + SCIM); this stack only grants access
data "aws_identitystore_user" "me" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = "prohres"
    }
  }
}

resource "aws_identitystore_group_membership" "me" {
  for_each          = aws_identitystore_group.this
  identity_store_id = local.identity_store_id
  group_id          = each.value.group_id
  member_id         = data.aws_identitystore_user.me.user_id
}
