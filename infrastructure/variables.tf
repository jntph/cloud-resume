variable "aws_region" {
  description = "Primary AWS region for most resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Apex domain name (e.g. jannapham.com). A Route 53 hosted zone for this domain must already exist."
  type        = string
}

variable "project" {
  description = "Short project name used in resource names and tags"
  type        = string
  default     = "cloud-resume"
}

variable "web_acl_id" {
  description = "ARN of the WAF WebACL to attach to CloudFront. Leave empty to detach WAF."
  type        = string
  default     = ""
}
