output "gha_role_arns" {
  description = "Roles the workflows assume via OIDC (role-to-assume)"
  value       = { for name, role in aws_iam_role.gha : name => role.arn }
}

output "org_role_arns" {
  description = "Roles the workflows chain into in the management account"
  value       = { for name, role in aws_iam_role.org : name => role.arn }
}
