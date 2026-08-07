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
  depends_on = [ module.vpc, module.file, module.ecr, module.sqs ]

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

module "ecr" {
  source = "./modules/ecr"

  for_each = local.ecrs

  name                     = each.key
  tags                     = each.value.tags
  image_tag_mutability     = each.value.image_tag_mutability
  force_delete             = each.value.force_delete
  scan_images_on_push      = each.value.scan_images_on_push

  encryption_configuration = each.value.enable_kms ? {encryption_type = each.value.encryption_type, kms_key = null} : null
  image_tag_mutability_exclusion_filter = each.value.enable_image_tag_exclusion_filter ? each.value.image_tag_exclusion_filter : []
}


module "sqs" {
  source = "./modules/sqs"

  for_each = local.sqss

  name = each.key
  tags = each.value.tags

  delay_seconds = each.value.delay_seconds
  max_message_size = each.value.max_message_size
  message_retention_seconds = each.value.message_retention_seconds
  receive_wait_time_seconds = each.value.receive_wait_time_seconds
  visibility_timeout_seconds = each.value.visibility_timeout_seconds

  fifo_queue = each.value.fifo_queue 
  content_based_deduplication = each.value.content_based_deduplication
  fifo_throughput_limit = each.value.fifo_throughput_limit
  deduplication_scope = each.value.deduplication_scope

  enable_kms = each.value.enable_kms
  kms_data_key_reuse_period_seconds = each.value.kms_data_key_reuse_period_seconds
  # kms_key_id = module.kms[each.value.kms_name].kms_key_id
  kms_key_id = null
  sqs_managed_sse_enabled = each.value.sqs_managed_sse_enabled
}