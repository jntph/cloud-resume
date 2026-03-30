module "backend" {
  source = "./modules/backend"
}

module "frontend" {
  source = "./modules/frontend"

  domain_name = var.domain_name
  project     = var.project
  bucket_name = "janna-cloud"
  web_acl_id  = var.web_acl_id

  # Pass both provider configurations into the module.
  # The us_east_1 alias is required for ACM cert provisioning.
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
