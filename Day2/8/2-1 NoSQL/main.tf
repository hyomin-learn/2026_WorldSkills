terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
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

#=================== network ===================
module "network" {
  source = "./modules/network"

  project              = var.project
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = var.azs
}

#=================== kms ===================
module "kms" {
  source = "./modules/kms"

  project = var.project
}

#=================== s3 (app artifacts) ===================
module "s3_app" {
  source = "./modules/s3_app"

  project                  = var.project
  docdb_client_py_path     = var.docdb_client_py_path
  retail_dataset_json_path = var.retail_dataset_json_path
}

#=================== docdb ===================
module "docdb" {
  source = "./modules/docdb"

  project                  = var.project
  private_subnet_ids       = module.network.private_subnet_ids
  docdb_security_group_id  = module.network.docdb_security_group_id
  kms_key_arn              = module.kms.key_arn
  master_username          = var.docdb_master_username
  master_password          = var.docdb_master_password
  instance_class           = var.docdb_instance_class
  backup_retention_period  = var.docdb_backup_retention_period
}

#=================== secrets ===================
module "secrets" {
  source = "./modules/secrets"

  project     = var.project
  kms_key_arn = module.kms.key_arn
  username    = var.docdb_master_username
  password    = var.docdb_master_password
  docdb_host  = module.docdb.cluster_endpoint
}

#=================== ec2 (client application) ===================
module "ec2" {
  source = "./modules/ec2"

  project                   = var.project
  public_subnet_id          = module.network.public_subnet_id
  client_security_group_id  = module.network.client_security_group_id
  instance_type             = var.ec2_instance_type
  key_name                  = var.ec2_key_name
  secret_arn                = module.secrets.secret_arn
  kms_key_arn               = module.kms.key_arn
  app_bucket_name           = module.s3_app.bucket_id
  app_bucket_arn            = module.s3_app.bucket_arn
  docdb_client_object_key   = module.s3_app.docdb_client_object_key
  retail_dataset_object_key = module.s3_app.retail_dataset_object_key

  depends_on = [module.docdb, module.secrets]
}
