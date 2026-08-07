module "vpc" {
  source      = "./modules/vpc"
  project     = var.project
  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.subnet_cidr
  az          = var.az
}

module "ec2" {
  source        = "./modules/ec2"
  project       = var.project
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.subnet_id
  instance_type = var.instance_type
}

module "sns" {
  source  = "./modules/sns"
  project = var.project
}

module "lambda" {
  source             = "./modules/lambda"
  project            = var.project
  security_group_id  = module.ec2.security_group_id
  sns_topic_arn      = module.sns.topic_arn
  runtime            = var.lambda_runtime
  timeout            = var.lambda_timeout
}

module "cloudtrail" {
  source  = "./modules/cloudtrail"
  project = var.project
}

module "eventbridge" {
  source                = "./modules/eventbridge"
  project               = var.project
  lambda_function_name  = module.lambda.function_name
  lambda_arn            = module.lambda.lambda_arn

  depends_on = [module.cloudtrail]
}
