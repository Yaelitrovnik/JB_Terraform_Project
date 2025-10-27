terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region                  = "us-east-2"
  shared_credentials_file = pathexpand("~/.aws/credentials") # or default
  profile                 = "default"                        # use your AWS CLI profile
}
