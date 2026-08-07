locals {
  parameter = "skills-sqs"

  az_override  = ["a", "c"]

  azs = [
    for az in data.aws_availability_zones.az.names :
    az if contains(local.az_override, substr(az, -1, 1))
  ]
}

locals {
  vpcs = {
    "${local.parameter}-vpc" = {
      vpc_cidr         = "10.0.0.0/16"
      default_rtb_tags = {Name = "${local.parameter}-default-rtb"}
      default_sg_tags  = {Name = "${local.parameter}-default-sg"}

      vpc_tags = {Name = "${local.parameter}-vpc"}

      enable_igw       = true
      enable_natgw     = true

      types = [
        {
          type         = "public"
          sn_cidrs     = ["10.0.0.0/24", "10.0.1.0/24"]
          sn_tags      = {Name = "${local.parameter}-public-$1"}

          rtb_tags     = {Name = "${local.parameter}-public-rtb"}

          igw_tags     = {Name = "${local.parameter}-igw"}
        },
        {
          type         = "private"
          sn_cidrs     = ["10.0.2.0/24", "10.0.3.0/24"]
          sn_tags      = {Name = "${local.parameter}-private-$1"}

          rtb_tags     = {Name = "${local.parameter}-private-$1-rtb"}

          natgw_tags   = {Name = "${local.parameter}-natgw-$1"}
        },
      ]
    }
  }
}

locals {
  security_groups = {
    "${local.parameter}-eks-nodegroup-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-eks-nodegroup-sg"
      security_group_tags = {Name = "${local.parameter}-eks-nodegroup-sg"}
      ingress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
      egress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
    }
  }
}

locals {
  ec2s = {
    "${local.parameter}-bastion" = {
      vpc_name                = "${local.parameter}-vpc"
      subnet_name             = "${local.parameter}-public-a"

      instance_tags = {Name = "${local.parameter}-bastion"}
      
      instance_type           = "t3.medium"
      userdata                = "/ec2/bastion/userdata.sh"
      
      enable_public_ip        = true
      enable_eip              = false
      eip_tags = {Name = "${local.parameter}-bastion-eip"}

      root_block_device = {
        volume_size           = 30
        volume_type           = "gp3"
        delete_on_termination = true
      }

      security_group_name     = "${local.parameter}-bastion-sg"
      security_group_tags = {Name = "${local.parameter}-bastion-sg"}
      ingress_ports = [
        {from_port = 22, to_port = 22, protocol = "tcp", cidr_block = "0.0.0.0/0"},
      ]

      egress_ports = [
        {from_port = 22, to_port = 22, protocol = "tcp", cidr_block = "0.0.0.0/0"},
        {from_port = 80, to_port = 80, protocol = "tcp", cidr_block = "0.0.0.0/0"},
        {from_port = 443, to_port = 443, protocol = "tcp", cidr_block = "0.0.0.0/0"}
      ]
      
      enable_create_keypair = true
      keypair_name          = "${local.parameter}"
      keypair_file_path     = "${path.cwd}/${local.parameter}.pem"

      enable_create_iam_role = true
      iam_role_name         = "${local.parameter}-bastion-role"
      instance_profile_name = "${local.parameter}-bastion-profile"
      iam_policies          = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    },
  }
}

locals {
  ecrs = {
    "${local.parameter}-ecr" = {
      tags = {Name = "${local.parameter}-ecr"}

      image_tag_mutability              = "MUTABLE"
      force_delete                      = true
      scan_images_on_push               = false

      enable_kms                        = false
      kms_key_name                      = "${local.parameter}/kms/ecr"
      encryption_type                   = "KMS"

      enable_image_tag_exclusion_filter = false
      image_tag_exclusion_filter = [
        {filter = "latest", filter_type = "WILDCARD"},
      ]
    }
  }
}

locals {
  sqss = {
    "${local.parameter}-queue" = {
      tags = {Name = "${local.parameter}-queue"}
      
      delay_seconds = 0
      max_message_size = 262144
      message_retention_seconds = 345600
      receive_wait_time_seconds = 0
      visibility_timeout_seconds = 30

      fifo_queue = false
      content_based_deduplication = false
      fifo_throughput_limit = "perMessageGroupId" # perQueue
      deduplication_scope = "queue" # messageGroup

      enable_kms = false
      kms_name = "${local.parameter}/kms/sqs"
      kms_data_key_reuse_period_seconds = 300
      sqs_managed_sse_enabled = false
    }
  }
}