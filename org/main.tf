# The organization itself is read-only here: managing aws_organizations_organization
# risks dropping service access principals (e.g. sso.amazonaws.com) on apply.
data "aws_organizations_organization" "this" {}

locals {
  root_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy" "deny_leave_and_close_account" {
  name        = "DenyLeaveAndCloseAccount"
  description = "Prevents member accounts from leaving the organization and self closure"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../policies/deny-leave-and-close-account.json")
}

resource "aws_organizations_policy_attachment" "deny_leave_root" {
  policy_id = aws_organizations_policy.deny_leave_and_close_account.id
  target_id = local.root_id
}

# Target structure: Infrastructure, Workloads (Prod / NonProd), Suspended
resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "nonprod" {
  name      = "NonProd"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "suspended" {
  name      = "Suspended"
  parent_id = local.root_id
}

resource "aws_organizations_policy" "security_baseline" {
  name        = "SecurityBaseline"
  description = "Applies to every member account: approved regions, audit protection, no long-lived IAM credentials"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../policies/security-baseline.json")
}

resource "aws_organizations_policy" "cost_guardrails" {
  name        = "CostGuardrails"
  description = "Denies GPU, bare metal and very large EC2 instance types"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../policies/cost-guardrails.json")
}

resource "aws_organizations_policy" "deny_all" {
  name        = "DenyAll"
  description = "Quarantine for accounts pending closure"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/../policies/deny-all.json")
}

resource "aws_organizations_policy_attachment" "security_baseline_root" {
  policy_id = aws_organizations_policy.security_baseline.id
  target_id = local.root_id
}

resource "aws_organizations_policy_attachment" "cost_guardrails_root" {
  policy_id = aws_organizations_policy.cost_guardrails.id
  target_id = local.root_id
}

resource "aws_organizations_policy_attachment" "deny_all_suspended" {
  policy_id = aws_organizations_policy.deny_all.id
  target_id = aws_organizations_organizational_unit.suspended.id
}
