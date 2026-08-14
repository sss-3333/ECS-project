terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — bucket was created manually as a one-time bootstrap
  # step (Terraform can't create the bucket it also stores its own
  # state in — chicken-and-egg). use_lockfile enables S3-native state
  # locking (GA since Terraform 1.11) via conditional writes, so no
  # DynamoDB table is needed for locking.
  backend "s3" {
    bucket       = "trackance-tfstate-sss3333"
    key          = "ecs-project/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
