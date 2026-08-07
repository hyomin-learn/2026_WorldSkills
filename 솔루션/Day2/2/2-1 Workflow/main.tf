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

#=================== S3 ===================

module "s3" {
  source = "./modules/s3"

  bucket_name = "${var.bucket_name_prefix}-${var.student_number}"
}

#=================== DynamoDB ===================

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = var.dynamodb_table_name
}

#=================== IAM ===================

module "iam" {
  source = "./modules/iam"

  lambda_role_name       = var.lambda_role_name
  stepfunction_role_name = var.stepfunction_role_name
  bucket_arn             = module.s3.bucket_arn
  dynamodb_table_arn     = module.dynamodb.table_arn
}

#=================== Lambda (성적 처리 함수) ===================

module "lambda_score" {
  source = "./modules/lambda-score"

  function_name = var.score_function_name
  role_arn      = module.iam.lambda_role_arn
  s3_bucket     = module.s3.bucket_id
  ddb_table     = module.dynamodb.table_name
}

#=================== Step Functions ===================

module "stepfunctions" {
  source = "./modules/stepfunctions"

  state_machine_name   = var.state_machine_name
  role_arn             = module.iam.stepfunction_role_arn
  lambda_function_arn  = module.lambda_score.function_arn
  bucket_name          = module.s3.bucket_id
}

#=================== Lambda (트리거 함수) ===================

module "lambda_trigger" {
  source = "./modules/lambda-trigger"

  function_name     = var.trigger_function_name
  role_arn          = module.iam.lambda_role_arn
  state_machine_arn = module.stepfunctions.state_machine_arn
}

#=================== S3 Event Notification ===================

module "s3_notification" {
  source = "./modules/s3-notification"

  bucket_id             = module.s3.bucket_id
  bucket_arn            = module.s3.bucket_arn
  lambda_function_arn   = module.lambda_trigger.function_arn
  lambda_function_name  = module.lambda_trigger.function_name
}
