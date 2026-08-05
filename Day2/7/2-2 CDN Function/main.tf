terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 5.30"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = var.project
    }
  }
}

#=================== s3 ===================

module "s3" {
  source = "./modules/s3"

  project = var.project
}


#=================== Cloudfront ===================

module "cloudfront" {
  source = "./modules/cloudfront"

  project                      = var.project
  bucket_id                    = module.s3.bucket_id
  bucket_arn                   = module.s3.bucket_arn
  bucket_regional_domain_name  = module.s3.bucket_regional_domain_name
}
