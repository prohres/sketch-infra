variable "account_id" {
  description = "Management account (TF_VAR_account_id: accounts.env locally, ci-templates tf-setup in CI)"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "A 12-digit AWS account id."
  }
}
