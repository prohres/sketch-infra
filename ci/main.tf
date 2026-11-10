# This stack holds CI's own trust roots, so it is applied manually (like bootstrap/), never by CI.
locals {
  repo            = "prohres/sketch-infra"
  root_account_id = "183691668268"
  state_bucket    = "sketch-tfstate-183691668268"

  # Built as strings: the org roles trust the gha roles by reference, so referencing back would form a cycle
  org_role_arns = {
    "org-tf-plan"  = "arn:aws:iam::${local.root_account_id}:role/org-tf-plan"
    "org-tf-apply" = "arn:aws:iam::${local.root_account_id}:role/org-tf-apply"
  }

  # Stacks CI may change; bootstrap/ and ci/ stay manual
  ci_stacks = ["org", "identity"]
}
