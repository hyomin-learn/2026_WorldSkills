terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
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


#=================== VPC ===================

module "vpc" {
  source             = "./modules/vpc"
  project            = var.project
  vpc_cidr           = "172.16.0.0/16"
  availability_zones = var.availability_zones
}


#=================== EC2 ===================

module "ec2" {
  source        = "./modules/ec2"
  project       = var.project
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_a_id
  sg_id         = module.vpc.event_sg_id
}


#=================== Lambda ===================
module "lambda" {
  source            = "./modules/lambda"
  project           = var.project
  security_group_id = module.vpc.event_sg_id
  instance_id       = module.ec2.instance_id
}

#=================== AWS Config ===================
module "config" {
  source  = "./modules/config"
  project = var.project
}

#=================== Cloudwatch ===================
module "cloudwatch" {
  source                   = "./modules/cloudwatch"
  project                  = var.project
  security_group_id        = module.vpc.event_sg_id
  instance_id              = module.ec2.instance_id
  function_arns            = module.lambda.function_arns
  function_names           = module.lambda.function_names
  required_tags_rule_name  = module.config.required_tags_rule_name
}
