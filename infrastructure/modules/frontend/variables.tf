variable "domain_name" {
  description = "Apex domain (e.g. jannapham.com). A Route 53 hosted zone must already exist for this domain."
  type        = string
}

variable "project" {
  description = "Short project name used in resource names"
  type        = string
}

variable "bucket_name" {
  description = "Override the S3 bucket name. If empty, defaults to project-website-accountid."
  type        = string
  default     = ""
}

variable "web_acl_id" {
  description = "ARN of the WAF WebACL to attach to CloudFront. Leave empty to detach WAF."
  type        = string
  default     = ""
}
