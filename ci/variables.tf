variable "account_id" {
  description = "Management account (TF_VAR_account_id: accounts.env locally, ci-templates tf-setup in CI)"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "A 12-digit AWS account id."
  }
}

variable "admin_account_id" {
  description = "CI hub account: OIDC provider and gha-* roles"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.admin_account_id))
    error_message = "A 12-digit AWS account id."
  }
}

variable "dev_account_id" {
  description = "Workload account: the app runtime (app-deploy role)"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.dev_account_id))
    error_message = "A 12-digit AWS account id."
  }
}
