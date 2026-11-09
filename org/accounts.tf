variable "account_emails" {
  description = "Root user email per member account, kept out of git in accounts.auto.tfvars"
  type        = map(string)
  sensitive   = true
}

locals {
  accounts = {
    "sketch-admin" = { ou = aws_organizations_organizational_unit.infrastructure.id }
    "sketch-dev"   = { ou = aws_organizations_organizational_unit.nonprod.id }
    "sketch-prod"  = { ou = aws_organizations_organizational_unit.prod.id }
  }
}

resource "aws_organizations_account" "this" {
  for_each          = local.accounts
  name              = each.key
  email             = var.account_emails[each.key]
  parent_id         = each.value.ou
  close_on_deletion = false

  lifecycle {
    prevent_destroy = true                                    # replacing an account means closing it
    ignore_changes  = [role_name, iam_user_access_to_billing] # not returned by the API after creation
  }

  # Accounts join an OU only after the Root-level guardrails are in force
  depends_on = [
    aws_organizations_policy_attachment.security_baseline_root,
    aws_organizations_policy_attachment.cost_guardrails_root,
  ]
}

# The admin account was managed as a standalone resource before; keep it, don't recreate it
moved {
  from = aws_organizations_account.admin
  to   = aws_organizations_account.this["sketch-admin"]
}

output "account_ids" {
  description = "Member account IDs by name, consumed by the identity stack"
  value       = { for name, account in aws_organizations_account.this : name => account.id }
}
