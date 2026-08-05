terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
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
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

#=================== Security Groups ===================
module "security_groups" {
  source = "./modules/security_groups"

  project = var.project
  vpc_id  = module.vpc.vpc_id
}

#=================== VPC Endpoints (STS, Lambda - required by MSK Lambda triggers) ===================
module "vpc_endpoints" {
  source = "./modules/vpc_endpoints"

  project            = var.project
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  msk_sg_id          = module.security_groups.msk_sg_id
}

#=================== S3 ===================
module "s3" {
  source = "./modules/s3"

  project    = var.project
  student_id = var.student_id
}

#=================== SNS ===================
module "sns" {
  source = "./modules/sns"

  project = var.project
}

#=================== DynamoDB ===================
module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = var.dynamodb_table_name
}

#=================== MSK ===================
module "msk" {
  source = "./modules/msk"

  project            = var.project
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  kafka_version      = var.msk_kafka_version
  instance_type      = var.msk_instance_type
  broker_count       = var.msk_broker_count
  security_group_id  = module.security_groups.msk_sg_id
}

#=================== EC2 (Producer) ===================
module "ec2" {
  source = "./modules/ec2"

  project               = var.project
  region                = var.region
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.vpc.private_subnet_ids[0]
  instance_type         = var.ec2_instance_type
  security_group_id     = module.security_groups.ec2_sg_id
  msk_cluster_arn             = module.msk.cluster_arn
  bootstrap_brokers_plaintext = module.msk.bootstrap_brokers_plaintext
  raw_topic_name        = var.raw_topic_name
  app_bucket_name       = module.s3.bucket_id
  app_object_key        = module.s3.app_object_key
}

#=================== MSK Topics ===================
module "msk_topics" {
  source = "./modules/msk_topics"

  create                           = var.manage_topics
  ec2_instance_id                 = module.ec2.instance_id
  region                           = var.region
  bootstrap_brokers_iam           = module.msk.bootstrap_brokers_iam
  raw_topic_name                  = var.raw_topic_name
  raw_topic_partitions            = var.raw_topic_partitions
  raw_topic_replication_factor    = var.raw_topic_replication_factor
  alert_topic_name                = var.alert_topic_name
  alert_topic_partitions          = var.alert_topic_partitions
  alert_topic_replication_factor  = var.alert_topic_replication_factor

  depends_on = [module.ec2, module.msk]
}

#=================== Lambda ===================
module "lambda" {
  source = "./modules/lambda"

  project             = var.project
  runtime             = var.lambda_runtime
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  security_group_id   = module.security_groups.lambda_sg_id
  msk_cluster_arn           = module.msk.cluster_arn
  msk_bootstrap_brokers_iam = module.msk.bootstrap_brokers_iam
  raw_topic_name      = var.raw_topic_name
  alert_topic_name    = var.alert_topic_name
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  sns_topic_arn       = module.sns.topic_arn
  s3_bucket_name      = module.s3.bucket_id
  s3_bucket_arn       = module.s3.bucket_arn

  depends_on = [module.msk_topics, module.vpc_endpoints]
}
