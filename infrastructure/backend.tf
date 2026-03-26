# Remote state keeps your tfstate file in S3 (encrypted, versioned) and uses
# a DynamoDB table for state locking so concurrent applies don't corrupt state.
#
# BOOTSTRAP: These two resources must exist BEFORE you run `terraform init`.
# Run the one-time bootstrap script first:
#   ./scripts/bootstrap-state.sh
#
terraform {
  backend "s3" {
    bucket         = "janna-cloud-resume-tfstate"
    key            = "cloud-resume/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
