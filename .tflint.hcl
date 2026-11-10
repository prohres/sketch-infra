# Read by the lint job of ci-templates tf-plan.yml (tflint --recursive from the repo root)
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.50.0" # pinned like any dependency; bump deliberately
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
