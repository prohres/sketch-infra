terraform {
  backend "s3" {
    bucket       = "sketch-tfstate-183691668268"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-central-1"
    profile      = "sketch-root"
    encrypt      = true
    use_lockfile = true # lock file next to the state in S3, no DynamoDB table needed
  }
}
