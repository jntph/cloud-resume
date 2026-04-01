# ============================================================
# DATA SOURCES
# ============================================================

# Looks up the hosted zone you already registered in Route 53.
data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

# Used to inject the AWS account ID into the bucket name, keeping it globally unique.
data "aws_caller_identity" "current" {}

# AWS-managed cache policy — optimizes hit rate for static files.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}


# ============================================================
# WAF WebACL (us-east-1 — CloudFront requirement)
# ============================================================

resource "aws_wafv2_web_acl" "cloudfront" {
  provider    = aws.us_east_1
  name        = "CreatedByCloudFront-985e48a4"
  description = "WAF for ${var.project} CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitPerIP"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "CreatedByCloudFront-985e48a4"
    sampled_requests_enabled   = true
  }
}

# ============================================================
# ACM CERTIFICATE (us-east-1 — CloudFront requirement)
# ============================================================

resource "aws_acm_certificate" "this" {
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  # Recreate the new cert before destroying the old one so CloudFront
  # always has a valid cert attached during rotation.
  lifecycle {
    create_before_destroy = true
  }
}

# ACM requires a CNAME record in Route 53 to prove you own the domain.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.this.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
}


# ============================================================
# S3 BUCKET (private — only CloudFront can read it via OAC)
# ============================================================

locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.project}-website-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "website" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3 (AES-256) is free and covers the compliance checkbox.
# Switch to SSE-KMS if your org requires customer-managed keys.
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# All four settings must be true — one alone is not enough.
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ============================================================
# CLOUDFRONT ORIGIN ACCESS CONTROL
# ============================================================
# OAC is the modern replacement for OAI. It uses SigV4 signing so CloudFront
# authenticates to S3 as a service principal — no shared credentials involved.

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.project}-oac"
  description                       = "OAC for ${var.project} S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


# ============================================================
# CLOUDFRONT DISTRIBUTION
# ============================================================

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.website.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.website.id}"
    viewer_protocol_policy = "redirect-to-https" # HTTP → HTTPS redirect at edge
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true                # Brotli/gzip at the edge, free

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # S3 returns 403 (not 404) for missing objects when public access is blocked.
  # Map both to index.html so direct URL loads work correctly.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
    ssl_support_method       = "sni-only"          # Required for custom domains
    minimum_protocol_version = "TLSv1.2_2021"      # Drops TLS 1.0/1.1
  }
}


# ============================================================
# S3 BUCKET POLICY — allow CloudFront OAC only
# ============================================================
# The condition on AWS:SourceArn means ONLY this specific CloudFront
# distribution can read from S3 — not any other distribution in any account.

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.s3_cloudfront_oac.json

  # Public access block must be fully applied before Terraform writes any policy,
  # otherwise it can race and leave the bucket briefly exposed.
  depends_on = [aws_s3_bucket_public_access_block.website]
}

data "aws_iam_policy_document" "s3_cloudfront_oac" {
  statement {
    sid     = "AllowCloudFrontServicePrincipal"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}


# ============================================================
# ROUTE 53 — A alias records (apex + www)
# ============================================================

resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
