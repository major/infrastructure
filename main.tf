terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.53.0"
    }
  }
  backend "s3" {
    bucket = "majors-terraform-state"
    key    = "terraform/infrastructure.tfstate"
    region = "us-east-2"
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      deployed = "with-terraform"
    }
  }
}
