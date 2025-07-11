# define AWS provider and region
provider "aws" {
  region = var.aws_region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  /*
  backend "s3" {
    bucket         = "YOUR STATE BUCKET NAME"
    key            = "terraform.tfstate"
    region         = "YOUR AWS REGION"
    dynamodb_table = "YOUR STATE DYNAMODB TABLE"
    encrypt        = true
  }
  */

  /*
  backend "local" {
    path = "./terraform.tfstate"
  }
  */
}