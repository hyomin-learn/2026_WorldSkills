terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "./modules/vpc"

  project      = var.project
  cluster_name = var.cluster_name
  vpc_cidr     = "10.0.0.0/16"

  availability_zones   = ["${var.region}a", "${var.region}c"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.16.0/20", "10.0.32.0/20"]
}

module "iam" {
  source        = "./modules/iam"
  instance_name = "${var.project}-bastion"
}

module "ecr" {
  source     = "./modules/ecr"
  repo_name  = "${var.project}-app"
}

data "aws_caller_identity" "current" {}

module "alb" {
  source            = "./modules/alb"
  project           = var.project
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

module "s3" {
  source         = "./modules/s3"
  project        = var.project
  kubernetes_dir = "${path.root}/kubernetes"
}

module "ec2" {
  source = "./modules/ec2"

  instance_name         = "${var.project}-bastion"
  keypair_name          = "${var.project}-key"
  instance_type         = "t3.small"
  public_subnet_id      = module.vpc.public_subnet_ids[0]
  bastion_sg_id         = module.vpc.bastion_sg_id
  instance_profile_name = module.iam.instance_profile_name

  region             = var.region
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  ecr_repository_url = module.ecr.repository_url

  availability_zones = ["${var.region}a", "${var.region}c"]
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  artifacts_bucket  = module.s3.bucket_name
  competitor_number = var.competitor_number
  auto_deploy       = var.auto_deploy

  alb_sg_id      = module.alb.alb_sg_id
  app_tg_arn     = module.alb.app_tg_arn
  grafana_tg_arn = module.alb.grafana_tg_arn

  admin_principal_arn = data.aws_caller_identity.current.arn

  depends_on = [module.s3]
}
