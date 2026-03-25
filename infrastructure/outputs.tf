output "website_url" {
  description = "Public HTTPS URL of the resume"
  value       = "https://${var.domain_name}"
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain (useful before DNS propagates)"
  value       = module.frontend.cloudfront_domain
}

output "cloudfront_distribution_id" {
  description = "Distribution ID — used in CI/CD for cache invalidations"
  value       = module.frontend.cloudfront_distribution_id
}

output "s3_bucket_name" {
  description = "S3 bucket that holds the static files"
  value       = module.frontend.s3_bucket_name
}
