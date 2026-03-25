variable "domain_name" {
  description = "Apex domain (e.g. jannapham.com). A Route 53 hosted zone must already exist for this domain."
  type        = string
}

variable "project" {
  description = "Short project name used in resource names"
  type        = string
}
