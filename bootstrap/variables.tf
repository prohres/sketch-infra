variable "account_id" {
  description = "Management account (TF_VAR_account_id: accounts.env locally, ci-templates tf-setup in CI)"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "A 12-digit AWS account id."
  }
}

variable "dev_account_id" {
  description = "Workload account: kantor-infra CI roles get access to their own state key"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.dev_account_id))
    error_message = "A 12-digit AWS account id."
  }
}
