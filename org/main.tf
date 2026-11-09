# The organization itself is read-only here: managing aws_organizations_organization
# risks dropping service access principals (e.g. sso.amazonaws.com) on apply.
data "aws_organizations_organization" "this" {}

locals {
  root_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "labs" {
  name      = "Labs"
  parent_id = local.root_id
}

resource "aws_organizations_policy" "deny_leave_and_close_account" {
  name        = "DenyLeaveAndCloseAccount"
  description = "Prevents member accounts from leaving the organization and self closure"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../policies/deny-leave-and-close-account.json")
}

resource "aws_organizations_policy" "lab_guardrails" {
  name        = "LabGuardrails"
  description = "Lab guardrails: regions, audit, expensive EC2, no IAM keys"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../policies/lab-guardrails.json")
}

resource "aws_organizations_policy_attachment" "deny_leave_root" {
  policy_id = aws_organizations_policy.deny_leave_and_close_account.id
  target_id = local.root_id
}

resource "aws_organizations_policy_attachment" "lab_guardrails_labs" {
  policy_id = aws_organizations_policy.lab_guardrails.id
  target_id = aws_organizations_organizational_unit.labs.id
}
