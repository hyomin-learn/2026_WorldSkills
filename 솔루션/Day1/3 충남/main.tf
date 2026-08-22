module "file" {
  source = "./modules/file"
}

module "vpc" {
  source = "./modules/vpc"

  for_each = local.vpcs

  az_override      = local.az_override
  azs              = local.azs
  enable_igw       = each.value.enable_igw
  enable_natgw     = each.value.enable_natgw

  default_rtb_tags = each.value.default_rtb_tags
  default_sg_tags  = each.value.default_sg_tags
  vpc_name         = each.key
  vpc_cidr         = each.value.vpc_cidr
  vpc_tags         = each.value.vpc_tags
  types            = each.value.types
}

module "security_group" {
  depends_on = [ module.vpc ]
  source = "./modules/security_group"

  for_each = local.security_groups

  vpc_id                = module.vpc[each.value.vpc_name].vpc_id

  security_group_name   = each.value.security_group_name
  security_group_tags   = each.value.security_group_tags
  ingress_ports         = each.value.ingress_ports
  egress_ports          = each.value.egress_ports
}

module "ec2" {
  depends_on = [ module.vpc, module.security_group, module.iam, module.lambda, module.dynamodb, module.file ]

  source = "./modules/ec2"

  for_each = local.ec2s

  vpc_id                = module.vpc[each.value.vpc_name].vpc_id
  subnet_id             = module.vpc[each.value.vpc_name].subnet_ids[each.value.subnet_name]
  name                  = each.key

  instance_type         = each.value.instance_type
  userdata              = each.value.userdata
  instance_tags         = each.value.instance_tags

  enable_public_ip      = each.value.enable_public_ip
  enable_eip            = each.value.enable_eip
  eip_tags              = each.value.eip_tags

  root_block_device     = each.value.root_block_device

  security_group_name   = each.value.security_group_name
  security_group_tags   = each.value.security_group_tags
  ingress_ports         = each.value.ingress_ports
  egress_ports          = each.value.egress_ports

  enable_create_keypair = each.value.enable_create_keypair
  keypair_name          = each.value.keypair_name
  keypair_file_path     = each.value.keypair_file_path

  enable_create_iam_role = each.value.enable_create_iam_role
  iam_role_name         = each.value.iam_role_name
  instance_profile_name = each.value.instance_profile_name
  iam_policies          = each.value.iam_policies
}

module "kms" {
  source = "./modules/kms"

  for_each = local.kmss

  name                    = each.key
  tags                    = each.value.tags
  alias_name              = each.value.alias_name
  key_usage               = each.value.key_usage
  deletion_window_in_days = each.value.deletion_window_in_days
  statements              = each.value.statements
}

module "iam" {
  source = "./modules/iam"

  for_each = local.iams

  role_name             = each.key
  role_tags             = each.value.role_tags
  role_statements       = each.value.role_statements
  policy_statements     = each.value.policy_statements
  enable_inline_policy  = each.value.enable_inline_policy
  inline_policy_name    = each.value.inline_policy_name
  enable_custom_policy  = each.value.enable_custom_policy
  policy_name           = each.value.policy_name
  policy_tags           = each.value.policy_tags
  enable_managed_policy = each.value.enable_managed_policy
  managed_policy_arns   = each.value.managed_policy_arns
}

module "ecr" {
  depends_on = [ module.kms ]

  source = "./modules/ecr"

  for_each = local.ecrs

  name                     = each.key
  tags                     = each.value.tags
  image_tag_mutability     = each.value.image_tag_mutability
  force_delete             = each.value.force_delete
  scan_images_on_push      = each.value.scan_images_on_push

  encryption_configuration = each.value.enable_kms ? {
    encryption_type = each.value.encryption_type
    kms_key = module.kms[each.value.kms_key_name].kms_arn
  } : null
  image_tag_mutability_exclusion_filter = each.value.enable_image_tag_mutability_exclusion_filter ? each.value.image_tag_mutability_exclusion_filter : []
}

module "dynamodb" {
  depends_on = [ module.kms, module.iam, module.lambda ]
  source = "./modules/dynamodb"

  for_each = local.dynamodbs

  name                        = each.key
  tags                        = each.value.tags
  billing_mode                = each.value.billing_mode
  read_capacity               = each.value.read_capacity
  write_capacity              = each.value.write_capacity
  deletion_protection_enabled = each.value.deletion_protection_enabled
  hash_key                    = each.value.hash_key
  range_key                   = each.value.range_key
  attributes                  = each.value.attributes
  server_side_encryption = each.value.enable_kms ? {
    enabled = each.value.enable_kms
    kms_key_arn = module.kms[each.value.kms_key_name].kms_arn
  } : null
  ttl = each.value.enable_ttl ? {
    enabled = each.value.enable_ttl
    attribute_name = each.value.ttl_attribute_name
  } : null
  point_in_time_recovery = each.value.enable_point_in_time_recovery ? {
    enabled = each.value.enable_point_in_time_recovery
    recovery_period_in_days = each.value.recovery_period_in_days
  } : null
  local_secondary_indexes = each.value.enable_local_secondary_indexes ? each.value.local_secondary_indexes : null
  global_secondary_indexes = each.value.enable_global_secondary_indexes ? each.value.global_secondary_indexes : null
  replicas = each.value.enable_replicas ? [
    for r in each.value.replicas : {
      region_name = r.region_name
      propagate_tags = r.propagate_tags
      point_in_time_recovery = r.enable_replica_point_in_time_recovery ? r.point_in_time_recovery : null
      consistency_mode = r.consistency_mode
      kms_key_arn = r.enable_replica_kms ? module.kms[r.kms_key_name].kms_arn : null
    }
  ] : null
  enable_resource_policy = each.value.enable_resource_policy
  statements = each.value.enable_resource_policy ? each.value.statements : null
  items = each.value.enable_items ? each.value.items : null
}

module "lambda" {
  depends_on = [ module.vpc, module.kms ]
  source = "./modules/lambda"

  for_each = local.lambdas

  name                   = each.key
  tags                   = each.value.tags
  handler                = each.value.handler
  timeout                = each.value.timeout
  runtime                = each.value.runtime
  source_file_path       = each.value.source_file_path
  output_file_path       = each.value.output_file_path
  publish                = each.value.publish
  kms_key_arn            = each.value.enable_kms ? module.kms[each.value.kms_key_name].kms_arn : null  

  enable_lambda_edge     = each.value.enable_lambda_edge
  enable_upload_zip      = each.value.enable_upload_zip

  enable_lambda_function_url = each.value.enable_lambda_function_url
  lambda_function_url_auth_type = each.value.lambda_function_url_auth_type
  
  iam_role_name          = each.value.iam_role_name
  iam_role_tags          = each.value.iam_role_tags
  enable_managed_policy  = each.value.enable_managed_policy
  iam_policies           = each.value.iam_policies
  enable_custom_policy   = each.value.enable_custom_policy
  policy_name            = each.value.policy_name
  policy_tags            = each.value.policy_tags
  statements             = each.value.custom_policy_statements

  enable_environment     = each.value.enable_environment
  environment_variables  = each.value.environment_variables

  enable_logging         = each.value.enable_logging
  # log_group_name         = module.cloudwatch_logs[each.value.cloudwatch_logs_group_name].cw_log_group_name
  log_group_name         = null
  log_format             = each.value.log_format
  application_log_format = each.value.application_log_format
  system_log_format      = each.value.system_log_format

  enable_vpc_config      = each.value.enable_vpc_config
  vpc_id                 = each.value.enable_vpc_config ? module.vpc[each.value.vpc_name].vpc_id : null
  subnet_ids             = each.value.enable_vpc_config ? (each.value.internal ? module.vpc[each.value.vpc_name].private_subnet_ids : module.vpc[each.value.vpc_name].public_subnet_ids) : null
  security_group_name    = each.value.security_group_name
  security_group_tags    = each.value.security_group_tags
  ingress_ports          = each.value.ingress_ports
  egress_ports           = each.value.egress_ports
}

module "cloudwatch_logs" {
  depends_on = [ module.kms ] 

  source = "./modules/cloudwatch_logs"

  for_each = local.cloudwatch_logs

  name       = each.key
  tags       = each.value.tags
  kms_key_id = each.value.enable_kms ? module.kms[each.value.kms_key_name].kms_arn : null

  create_log_stream = each.value.create_log_stream
  log_stream_names = each.value.log_stream_names

  create_metric_filter = each.value.create_metric_filter
  metric_filters = each.value.metric_filters
}
  
module "s3" {
  depends_on = [ module.kms ]

  source = "./modules/s3"

  for_each = local.s3s

  name                   = each.key
  tags                   = each.value.tags
  enable_objects         = each.value.enable_objects
  objects                = each.value.objects
  enable_bucket_kms      = each.value.enable_bucket_kms
  enable_object_kms      = each.value.enable_object_kms
  server_side_encryption = each.value.enable_bucket_kms || each.value.enable_object_kms ? each.value.server_side_encryption : "AES256"
  kms_arn                = module.kms[each.value.kms_key_name].kms_arn
}


module "cloudfront" {
  depends_on = [ module.s3, module.waf ]

  source = "./modules/cloudfront"

  for_each = local.cloudfronts
  
  tags                            = each.value.tags
  origin_path                     = each.value.origin_path
  default_root_object             = each.value.default_root_object

  enable_cloudfront_function      = each.value.enable_cloudfront_function
  cloudfront_function_name        = each.value.cloudfront_function_name
  cloudfront_function_runtime     = each.value.cloudfront_function_runtime
  cloudfront_function_publish     = each.value.cloudfront_function_publish
  cloudfront_function_code_path   = each.value.cloudfront_function_code_path
  
  s3_bucket_id                    = module.s3[each.value.s3_bucket_name].s3_bucket_id
  s3_bucket_arn                   = module.s3[each.value.s3_bucket_name].s3_bucket_arn
  s3_bucket_regional_domain_name  = module.s3[each.value.s3_bucket_name].s3_bucket_regional_domain_name

  lambda_function_url             = module.lambda[each.value.lambda_name].lambda_function_url

  enable_waf                      = each.value.enable_waf
  waf_id                          = module.waf[each.value.waf_name].waf_arn
}

module "waf" {
  source = "./modules/waf"

  providers = { aws = aws.us_east_1 }

  for_each = local.wafs

  name                 = each.key
  tags                 = each.value.tags
  metric_name          = each.value.metric_name
  enable_cloudfront    = each.value.enable_cloudfront
  alb_arn              = null
  enable_managed       = each.value.enable_managed
  managed_rules        = each.value.managed_rules
  enable_custom        = each.value.enable_custom
  custom_rules         = each.value.custom_rules
  enable_logging       = each.value.enable_logging
  log_destination_arns = each.value.enable_logging ? null : []

  default_action         = each.value.default_action
  default_block_response = each.value.default_block_response
  custom_response_body   = each.value.custom_response_body
}