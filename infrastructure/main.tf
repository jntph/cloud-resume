module "frontend" {
  source = "./modules/frontend"

  domain_name = var.domain_name
  project     = var.project

  # Pass both provider configurations into the module.
  # The us_east_1 alias is required for ACM cert provisioning.
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
