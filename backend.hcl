# Shared backend settings (partial configuration): backend blocks can't use variables.
# terraform init -backend-config=../backend.hcl -backend-config=../backend.local.hcl (bucket; in CI: backend-bucket)
region       = "eu-central-1"
encrypt      = true
use_lockfile = true # lock file next to the state in S3, no DynamoDB table needed
