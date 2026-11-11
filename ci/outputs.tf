output "gha_role_arns" {
  description = "Roles the workflows assume via OIDC (role-to-assume)"
  value       = { for name, role in aws_iam_role.gha : name => role.arn }
}

output "org_role_arns" {
  description = "Roles the workflows chain into in the management account"
  value       = { for name, role in aws_iam_role.org : name => role.arn }
}

output "plan_bucket" {
  description = "Private bucket for saved plans (plan-bucket input of the apply workflow)"
  value       = aws_s3_bucket.plans.bucket
}

output "app_role_arns" {
  description = "Roles the kantor workflows assume via OIDC (role-to-assume)"
  value       = { for name, role in aws_iam_role.app : name => role.arn }
}
