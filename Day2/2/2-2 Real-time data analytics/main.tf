terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project = var.project
    }
  }
}

provider "awscc" {
  region = "ap-northeast-2"
}

# --------------------------- VPC ---------------------------
module "vpc" {
  source  = "./modules/vpc"
  project = var.project
}

# --------------------------- Kinesis Data Stream ---------------------------
module "kinesis" {
  source  = "./modules/kinesis"
  project = var.project
}

# --------------------------- IAM ---------------------------
module "iam" {
  source     = "./modules/iam"
  project    = var.project
  stream_arn = module.kinesis.stream_arn
}

# --------------------------- EC2 + ALB ---------------------------
module "ec2" {
  source                = "./modules/ec2"
  project               = var.project
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  private_subnet_id     = module.vpc.private_subnet_ids[0]
  alb_sg_id             = module.vpc.alb_sg_id
  ec2_sg_id             = module.vpc.ec2_sg_id
  instance_profile_name = module.iam.ec2_instance_profile_name
  stream_name           = module.kinesis.stream_name
}

# --------------------------- Managed Apache Flink ---------------------------
module "flink" {
  source                 = "./modules/flink"
  project                = var.project
  service_execution_role = module.iam.flink_role_arn
}
