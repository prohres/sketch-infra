# Root emails follow one private rule kept out of git: a one-line template with an {account} placeholder,
# uploaded once by hand (README: Accounts). Both CI roles can read it; neither can write outside its state.
data "aws_s3_object" "account_email_template" {
  bucket = "sketch-tfstate-${var.account_id}"
  key    = "config/account-email-template.txt"
}

locals {
  accounts = {
    "sketch-admin" = { ou = aws_organizations_organizational_unit.infrastructure.id }
    "sketch-dev"   = { ou = aws_organizations_organizational_unit.nonprod.id }
    "sketch-prod"  = { ou = aws_organizations_organizational_unit.prod.id }
  }

  # Accounts on their way out (README: Accounts): quarantined in Suspended, closed when removed from here
  closing_accounts = toset([])

  email_template = sensitive(trimspace(data.aws_s3_object.account_email_template.body))
  account_emails = {
    for name in setunion(keys(local.accounts), local.closing_accounts) : name => replace(local.email_template, "{account}", name)
  }

  # Current root emails, read only to prove that the template reproduces them
  existing_emails = sensitive({ for account in data.aws_organizations_organization.this.accounts : account.name => account.email })
}

resource "aws_organizations_account" "this" {
  for_each          = local.accounts
  name              = each.key
  email             = local.account_emails[each.key] # sensitive: public repo, keep emails out of CI logs
  parent_id         = each.value.ou
  close_on_deletion = false

  lifecycle {
    prevent_destroy = true                                    # replacing an account means closing it
    ignore_changes  = [role_name, iam_user_access_to_billing] # not returned by the API after creation

    # Fail with a message that names the account, never the address: the provider's own validation
    # error prints an over-long email in clear text, and a changed email replaces (closes) the account
    precondition {
      condition     = length(local.account_emails[each.key]) <= 64 && can(regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", local.account_emails[each.key]))
      error_message = "Root email for account \"${each.key}\" is not a valid address of up to 64 characters: check the account name length and the private template."
    }
    precondition {
      condition     = !contains(keys(local.existing_emails), each.key) || local.existing_emails[each.key] == local.account_emails[each.key]
      error_message = "The private email template does not reproduce the current root email of account \"${each.key}\"."
    }
  }

  # Accounts join an OU only after the Root-level guardrails are in force
  depends_on = [
    aws_organizations_policy_attachment.security_baseline_root,
    aws_organizations_policy_attachment.cost_guardrails_root,
  ]
}

# Quarantine and closure: no prevent_destroy here on purpose, removing a name from local.closing_accounts
# closes that account (CloseAccount; its email, and so its name, can never be reused)
resource "aws_organizations_account" "closing" {
  for_each          = local.closing_accounts
  name              = each.key
  email             = local.account_emails[each.key]
  parent_id         = aws_organizations_organizational_unit.suspended.id
  close_on_deletion = true

  lifecycle {
    ignore_changes = [email, role_name, iam_user_access_to_billing] # the account is leaving: never replace it
  }
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
