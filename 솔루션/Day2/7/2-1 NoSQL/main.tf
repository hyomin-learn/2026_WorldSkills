terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
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

locals {
  reservation_table_name = "${var.project}-reservation-table"
  audit_table_name       = "${var.project}-audit-table"
  gsi_name               = "gsi-user-reservations"
  lambda_function_name   = "${var.project}-reservation-audit"
  app_instance_name      = "${var.project}-app-ec2"           
}

# ---------------------------- VPC ----------------------------
module "vpc" {
  source  = "./modules/vpc"
  project = var.project
}

# ---------------------------- IAM ----------------------------
module "iam" {
  source        = "./modules/iam"
  instance_name = local.app_instance_name
}

# ---------------------------- DynamoDB ----------------------------
module "dynamodb" {
  source                 = "./modules/dynamodb"
  project                = var.project
  reservation_table_name = local.reservation_table_name
  audit_table_name       = local.audit_table_name
  gsi_name               = local.gsi_name
}

# ---------------------------- Lambda ----------------------------
module "lambda" {
  source                  = "./modules/lambda"
  function_name           = local.lambda_function_name
  source_table_stream_arn = module.dynamodb.reservation_table_stream_arn
  audit_table_name        = module.dynamodb.audit_table_name
  audit_table_arn         = module.dynamodb.audit_table_arn
}

# ---------------------------- EC2 ----------------------------
module "ec2" {
  source                = "./modules/ec2"
  project               = var.project
  keypair_name          = "${var.project}-app-key"
  instance_name         = local.app_instance_name
  public_subnet_id      = module.vpc.public_subnet_ids[0]
  app_sg_id             = module.vpc.app_sg_id
  instance_profile_name = module.iam.instance_profile_name

  aws_region = var.region
  table_name = local.reservation_table_name
  gsi_name   = local.gsi_name

  depends_on = [module.dynamodb]
}
