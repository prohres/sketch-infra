data "aws_ssoadmin_instances" "this" {}

# Account IDs come straight from Organizations, so this stack does not depend on the org stack's state
data "aws_organizations_organization" "this" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  account_ids       = { for account in data.aws_organizations_organization.this.accounts : account.name => account.id }
}
