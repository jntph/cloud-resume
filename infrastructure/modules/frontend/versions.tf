terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # Declare the alias so Terraform knows to expect it from the root module.
      configuration_aliases = [aws.us_east_1]
    }
  }
}
