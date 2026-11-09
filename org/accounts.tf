variable "account_emails" {
  description = "Root user email per member account, kept out of git in accounts.auto.tfvars"
  type        = map(string)
  sensitive   = true
}

resource "aws_organizations_account" "admin" {
  name              = "sketch-admin"
  email             = var.account_emails["sketch-admin"]
  parent_id         = aws_organizations_organizational_unit.infrastructure.id
  close_on_deletion = false

  lifecycle {
    prevent_destroy = true                                    # replacing an account means closing it
    ignore_changes  = [role_name, iam_user_access_to_billing] # not returned by the API after creation
  }

  # Move only after the Root-level guardrails are in force, so the account is never unprotected
  depends_on = [
    aws_organizations_policy_attachment.security_baseline_root,
    aws_organizations_policy_attachment.cost_guardrails_root,
  ]
}
