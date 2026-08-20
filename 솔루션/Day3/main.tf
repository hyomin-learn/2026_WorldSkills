module "file" {
  source = "./modules/file"
}

module "vpc" {
  depends_on = [ module.file ]

  source = "./modules/vpc"
}

module "ec2" {
  depends_on = [ module.vpc, module.rds, module.rds_proxy, module.secrets_manager, module.file ]
  
  source    = "./modules/ec2"

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_a_id
}

module "rds" {
  source = "./modules/rds"
  vpc_id = module.vpc.vpc_id
  public_subnet_a_id = module.vpc.public_subnet_a_id
  public_subnet_c_id = module.vpc.public_subnet_c_id
  private_protect_subnet_a_id = module.vpc.private_protect_subnet_a_id
  private_protect_subnet_c_id = module.vpc.private_protect_subnet_c_id
  db_username = var.db_username
  db_password = var.db_password
}

module "secrets_manager" {
  depends_on = [module.rds]

  source = "./modules/secrets_manager"

  db_username = module.rds.username
  db_password = module.rds.password
  db_host     = ""
  db_port     = "3306"
  db_dbname   = module.rds.dbname
}

module "rds_proxy" {
  depends_on = [
    module.rds,
    module.secrets_manager
  ]

  source = "./modules/rds_proxy"

  vpc_id = module.vpc.vpc_id

  private_subnet_a_id = module.vpc.private_subnet_a_id
  private_subnet_b_id = module.vpc.private_subnet_c_id

  proxy_secret_arn = module.secrets_manager.proxy_secret_arn

  db_instance_identifier = "apdev-rds-instance"

  db_username = local.db_username
  db_password = local.db_password
}

module "s3" {
  source = "./modules/s3"
}

module "ecr" {
  source = "./modules/ecr"
}

module "cloudfront" {
  depends_on = [module.s3]

  source = "./modules/cloudfront"

  for_each = local.cloudfronts

  tags                          = each.value.tags
  origin_path                   = each.value.origin_path
  default_root_object           = each.value.default_root_object

  enable_cloudfront_function    = each.value.enable_cloudfront_function
  cloudfront_function_name      = each.value.cloudfront_function_name
  cloudfront_function_runtime   = each.value.cloudfront_function_runtime
  cloudfront_function_publish   = each.value.cloudfront_function_publish
  cloudfront_function_code_path = each.value.cloudfront_function_code_path

  s3_bucket_id                   = module.s3.s3_bucket_id
  s3_bucket_arn                  = module.s3.s3_bucket_arn
  s3_bucket_regional_domain_name = module.s3.s3_bucket_regional_domain_name

  cloudfront_bucket_domain_name  = module.s3.cloudfront_bucket_domain_name
  
  enable_waf                     = each.value.enable_waf
  waf_id                         = module.waf[each.value.waf_name].waf_arn
}

module "waf" {
  source = "./modules/waf"

  providers = { aws = aws.us_east_1 }

  for_each = local.wafs

  name                   = each.key
  tags                   = each.value.tags
  metric_name            = each.value.metric_name
  enable_cloudfront      = each.value.enable_cloudfront
  alb_arn                = null
  enable_managed         = each.value.enable_managed
  managed_rules          = each.value.managed_rules
  enable_custom          = each.value.enable_custom
  custom_rules           = each.value.custom_rules
  enable_logging         = each.value.enable_logging
  log_destination_arns   = null

  default_action         = each.value.default_action
  default_block_response = each.value.default_block_response
  custom_response_key    = each.value.custom_response_key
  custom_response_body   = each.value.custom_response_body
}

module "iam" {
  source = "./modules/iam" 
}