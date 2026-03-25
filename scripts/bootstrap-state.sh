#!/usr/bin/env bash
# bootstrap-state.sh
#
# Creates the S3 bucket and DynamoDB table that Terraform uses for remote state.
# Run this ONCE before `terraform init`. Everything else is managed by Terraform.
#
# Usage:
#   chmod +x scripts/bootstrap-state.sh
#   ./scripts/bootstrap-state.sh

set -euo pipefail

REGION="us-east-1"
STATE_BUCKET="YOUR_PROJECT_NAME-tfstate"   # <-- must be globally unique; change this
LOCK_TABLE="terraform-state-lock"

echo "==> Creating S3 state bucket: $STATE_BUCKET"
aws s3api create-bucket \
  --bucket "$STATE_BUCKET" \
  --region "$REGION"

echo "==> Enabling versioning on state bucket"
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

echo "==> Enabling SSE-S3 encryption on state bucket"
aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
      "BucketKeyEnabled": true
    }]
  }'

echo "==> Blocking all public access on state bucket"
aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "==> Creating DynamoDB lock table: $LOCK_TABLE"
aws dynamodb create-table \
  --table-name "$LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo ""
echo "Bootstrap complete. Update backend.tf with:"
echo "  bucket = \"$STATE_BUCKET\""
echo "  region = \"$REGION\""
echo "  dynamodb_table = \"$LOCK_TABLE\""
echo ""
echo "Then run: terraform init"
