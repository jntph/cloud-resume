output "cloudfront_domain" {
  description = "CloudFront distribution domain name (e.g. d1234.cloudfront.net)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_distribution_id" {
  description = "Distribution ID — referenced in CI/CD for cache invalidations"
  value       = aws_cloudfront_distribution.this.id
}

output "s3_bucket_name" {
  description = "Name of the S3 website bucket"
  value       = aws_s3_bucket.website.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 website bucket"
  value       = aws_s3_bucket.website.arn
}
