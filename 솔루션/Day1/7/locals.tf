locals {
  player_number = "105"

  parameter = "unicorn"

  az_override  = ["a", "b", "c"]

  azs = [
    for az in data.aws_availability_zones.az.names :
    az if contains(local.az_override, substr(az, -1, 1))
  ]
}

locals {
  vpcs = {
    "${local.parameter}-vpc" = {
      vpc_cidr         = "10.97.0.0/16"
      default_rtb_tags = null
      default_sg_tags  = {Name = "${local.parameter}-default-sg"}

      vpc_tags = {Name = "${local.parameter}-vpc"}

      enable_igw       = true
      enable_natgw     = true

      types = [
        {
          type         = "public"
          sn_cidrs     = ["10.97.0.0/24", "10.97.1.0/24", "10.97.2.0/24"]
          sn_tags      = {Name = "${local.parameter}-subnet-pub-$1"}

          rtb_tags     = {Name = "${local.parameter}-rt-pub"}

          igw_tags     = {Name = "${local.parameter}-igw"}
        },
        {
          type         = "private"
          sn_cidrs     = ["10.97.10.0/24","10.97.11.0/24", "10.97.12.0/24"]
          sn_tags      = {Name = "${local.parameter}-subnet-priv-$1"}

          rtb_tags     = {Name = "${local.parameter}-rt-priv-$1"}

          natgw_tags   = {Name = "${local.parameter}-nat-$1"}
        },
      ]
    }
  }
}

locals {
  flow_logs = {
    "${local.parameter}-vpc-flow-log" = {
      tags = {Name = "${local.parameter}-vpc-flow-log"}

      vpc_name = "${local.parameter}-vpc"

      enable_iam_role = true
      iam_role_name   = "${local.parameter}-flow-log-role"
      iam_role_tags   = { Name = "${local.parameter}-flow-log-role" }
      policy_name     = "${local.parameter}-flow-log-policy"
      policy_tags     = { Name = "${local.parameter}-flow-log-policy" }
      statements = [
        {
          effect = "Allow"
          actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
          resources = ["*"]
          conditions = []
        },
      ]

      log_destination_type = "cloud-watch-logs" # s3, kinesis-data-firehose
      log_destination_name = "/${local.parameter}/vpc/flow-log"
      log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status}"

      traffic_type = "ALL" # ACCEPT, REJECT
      max_aggregation_interval = 60
    },
  }
}

locals {
  security_groups = {
    "${local.parameter}-endpoint-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-endpoint-sg"
      security_group_tags = {Name = "${local.parameter}-endpoint-sg"}
      ingress_ports = [{from_port = 443, to_port = 443, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
      egress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
    },
    "${local.parameter}-eks-control-plane-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-eks-control-plane-sg"
      security_group_tags = {Name = "${local.parameter}-eks-control-plane-sg"}
      ingress_ports = [{from_port = 443, to_port = 443, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
      egress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
    },
    "${local.parameter}-alb-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-alb-sg"
      security_group_tags = {Name = "${local.parameter}-alb-sg"}
      ingress_ports = [{from_port = 80, to_port = 80, protocol = "tcp", prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront.id}]
      egress_ports = [{from_port = 8080, to_port = 8080, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
    },
    "${local.parameter}-mark-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-mark-sg"
      security_group_tags = {Name = "${local.parameter}-mark-sg"}
      ingress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
      egress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
    },
  }
}

locals {
  endpoints = {
    "ecr.dkr" = {
      vpc_name            = "${local.parameter}-vpc"
      type                = "private"
      security_group_name = "${local.parameter}-endpoint-sg"

      service_name        = "ecr.dkr"
      endpoint_type       = "Interface"
      enable_private_dns  = true
      tags = {Name = "${local.parameter}-ecr-dkr-ep"}
    },
    "ecr.api" = {
      vpc_name            = "${local.parameter}-vpc"
      type                = "private"
      security_group_name = "${local.parameter}-endpoint-sg"

      service_name        = "ecr.api"
      endpoint_type       = "Interface"
      enable_private_dns  = true
      tags = {Name = "${local.parameter}-ecr-api-ep"}
    },
    "s3" = {
      vpc_name            = "${local.parameter}-vpc"
      type                = "private"
      security_group_name = "${local.parameter}-endpoint-sg"

      service_name        = "s3"
      endpoint_type       = "Gateway"
      enable_private_dns  = false
      tags = {Name = "${local.parameter}-s3-ep"}
    },
  }
}

locals {
  ec2s = {
    "${local.parameter}-bastion" = {
      vpc_name                = "${local.parameter}-vpc"
      subnet_name             = "${local.parameter}-subnet-pub-a"

      instance_tags = {Name = "${local.parameter}-bastion"}
      
      instance_type           = "t3.medium"
      userdata                = "/ec2/bastion/userdata.sh"
      
      enable_public_ip        = true
      enable_eip              = true
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
  kmss = {
    "${local.parameter}-kms-app" = {
      tags = {Name = "${local.parameter}-kms-app"}
      
      alias_name              = "alias/${local.parameter}-kms-app"
      key_usage               = "ENCRYPT_DECRYPT"
      deletion_window_in_days = 7
      rotation_period_in_days = 90
      enable_key_rotation     = true
      multi_region            = false
      replica_region          = null
      replica_alias_name      = null

      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]}
          actions   = ["kms:*"]
          resources = ["*"]
          conditions = []
        },
      ]
    },
    "${local.parameter}-kms-data" = {
      tags = {Name = "${local.parameter}-kms-data"}

      alias_name              = "alias/${local.parameter}-kms-data"
      key_usage               = "ENCRYPT_DECRYPT"
      deletion_window_in_days = 7
      rotation_period_in_days = 90
      enable_key_rotation     = true
      multi_region            = false
      replica_region          = null
      replica_alias_name      = null

      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]}
          actions   = ["kms:*"]
          resources = ["*"]
          conditions = []
        },
        {
          effect = "Allow"
          principals = {type = "Service", identifiers = ["cloudfront.amazonaws.com"]}
          actions = ["kms:Decrypt", "kms:GenerateDataKey*"]
          resources = ["*"]
          conditions = []
        }
      ]
    },
    "${local.parameter}-kms-platform" = {
      tags = {Name = "${local.parameter}-kms-platform"}
      
      alias_name              = "alias/${local.parameter}-kms-platform"
      key_usage               = "ENCRYPT_DECRYPT"
      deletion_window_in_days = 7
      rotation_period_in_days = 90
      enable_key_rotation     = true
      multi_region            = true
      replica_region          = "ap-northeast-2"
      replica_alias_name        = "alias/${local.parameter}-kms-platform"

      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]}
          actions   = ["kms:*"]
          resources = ["*"]
          conditions = []
        },
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]}
          actions = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:GenerateDataKeyWithoutPlaintext"]
          resources = ["*"]
          conditions = []
        },
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]}
          actions = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
          resources = ["*"]
          conditions = [{test = "Bool", variable = "kms:GrantIsForAWSResource", values = ["true"]}]
        },
        {
          effect = "Allow"
          principals = {type = "Service", identifiers = ["logs.ap-northeast-2.amazonaws.com", "logs.us-east-1.amazonaws.com"]}
          actions = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
          resources = ["*"]
          conditions = []
        }
      ]
    },
  }
}

locals {
  iams = {
    "${local.parameter}-book-app-role" = {
      role_tags = {Name = "${local.parameter}-book-app-role"}
      service_name = "pods.eks"

      role_statements = [
        {
          effect    = "Allow"
          principals = {type = "Service", identifiers = ["pods.eks.amazonaws.com"]}
          actions   = ["sts:AssumeRole", "sts:TagSession"]
          resources = []
          conditions = []
        }
      ]
      
      policy_statements = [
        {
          effect    = "Allow"
          actions   = ["dynamodb:PutItem"]
          resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-concert-db"]
          conditions = []
        }
      ]

      enable_inline_policy  = false
      inline_policy_name    = "iam-inline-policy"

      enable_custom_policy = true
      policy_name          = "${local.parameter}-book-app-policy"
      policy_tags = {Name = "${local.parameter}-book-app-policy"}

      enable_managed_policy = false
      managed_policy_arns   = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    },
    "${local.parameter}-fluent-bit-role" = {
      role_tags = {Name = "${local.parameter}-fluent-bit-role"}

      role_statements = [
        {
          effect    = "Allow"
          principals = {type = "Service", identifiers = ["pods.eks.amazonaws.com"]}
          actions   = ["sts:AssumeRole", "sts:TagSession"]
          resources = []
          conditions = []
        }
      ]
      
      policy_statements = [
        {
          effect    = "Allow"
          actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
          resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/${local.parameter}/eks/book-app:*"]
          conditions = []
        },

      ]

      enable_inline_policy  = false
      inline_policy_name    = "iam-inline-policy"

      enable_custom_policy = true
      policy_name          = "${local.parameter}-fluent-bit-policy"
      policy_tags = {Name = "${local.parameter}-fluent-bit-policy"}

      enable_managed_policy = false
      managed_policy_arns   = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    },
    "${local.parameter}-audit-role" = {
      role_tags = {Name = "${local.parameter}-audit-role"}

      role_statements = [
        {
          effect    = "Allow"
          principals = {type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]}
          actions   = ["sts:AssumeRole"]
          resources = []
          conditions = [{test = "StringEquals", variable = "sts:ExternalId", values = ["unicorn-audit-2026${local.player_number}"]}]
        }
      ]
      
      policy_statements = [
        {
          effect    = "Allow"
          actions   = ["dynamodb:GetItem", "dynamodb:Query"]
          resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-concert-db"]
          conditions = []
        },
        {
          effect    = "Allow"
          actions   = ["ec2:DescribeVpcs"]
          resources = ["*"]
          conditions = []
        },
        {
          effect    = "Allow"
          actions   = ["eks:Describe"]
          resources = ["arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${local.parameter}-eks-cluster"]
          conditions = []
        },
      ]

      enable_inline_policy  = true
      inline_policy_name    = "${local.parameter}-audit-policy"

      enable_custom_policy = false
      policy_name          = "${local.parameter}-audit-policy"
      policy_tags = {Name = "${local.parameter}-audit-policy"}

      enable_managed_policy = false
      managed_policy_arns   = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    },
  }
}

locals {
  ecrs = {
    "${local.parameter}-concert-app" = {
      tags = {Name = "${local.parameter}-concert-app"}

      image_tag_mutability              = "IMMUTABLE_WITH_EXCLUSION"
      force_delete                      = true
      scan_images_on_push               = true

      enable_kms                        = true
      kms_key_name                      = "${local.parameter}-kms-data"
      encryption_type                   = "KMS"

      enable_image_tag_exclusion_filter = true
      image_tag_exclusion_filter = [
        {filter = "latest", filter_type = "WILDCARD"},
      ]
    },
  }
}

locals {
  dynamodbs = {
    "${local.parameter}-concert-db" = {
      tags = {Name = "${local.parameter}-concert-db"}

      billing_mode   = "PAY_PER_REQUEST" # PROVISIONED
      read_capacity  = 20
      write_capacity = 20
      deletion_protection_enabled = true

      enable_kms    = true
      kms_key_name  = "${local.parameter}-kms-data"

      hash_key = "booking_id"
      range_key = null

      attributes = [
        {name = "booking_id", type = "S"},
        {name = "client_id", type = "S"},
        {name = "created_at", type = "S"},
      ]
  
      enable_ttl = false
      ttl_attribute_name = "name"

      enable_point_in_time_recovery = true
      recovery_period_in_days = 35

      enable_local_secondary_indexes = false
      local_secondary_indexes = [
        {
          name = "name-index"
          range_key = null
          projection_type = "ALL" # ALL, KEYS_ONLY, INCLUDE
          non_key_attributes = null
        },
      ]

      enable_global_secondary_indexes = true
      global_secondary_indexes = [
        {
          name = "client-id-created-at-index"
          hash_key = "client_id"
          range_key = "created_at"
          projection_type = "ALL" # ALL, KEYS_ONLY, INCLUDE
          non_key_attributes = []
          read_capacity = 20
          write_capacity = 20
        },
      ]

      enable_replicas = false
      replicas = [
        {
          enable_replica_kms = false
          enable_replica_point_in_time_recovery = false
          region_name = "us-east-1"
          kms_key_name = "${local.parameter}-kms-data"
          propagate_tags = null
          point_in_time_recovery = null
          consistency_mode = null
        },
      ]

      enable_resource_policy = false
      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["*"]}
          actions = ["dynamodb:Query"]
          resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-concert-db"]
          conditions = []
        },
      ]

      enable_items = false
      items = [
        {key = "name", value_name = "demo", value_type = "S"},
        {key = "age", value_name = "22", value_type = "N"},
        {key = "country", value_name = "korea", value_type = "S"}
      ]
    }
  }
}

locals {
  target_groups = {
    "${local.parameter}-tg" = {
      vpc_name = "${local.parameter}-vpc"
      
      target_groups = [
        {
          name                  = "${local.parameter}-tg"
          port                  = 8080
          protocol              = "HTTP"
          target_type           = "lambda"
          deregistration_delay  = 30
          tags = {Name = "${local.parameter}-tg"}

          health_check = {
            protocol            = "HTTP"
            path                = "/"
            port                = 8080
            interval            = 5
            timeout             = 2
            healthy_threshold   = 2
            unhealthy_threshold = 2
            matcher             = "200-399"
          }
        }
      ]

      enable_attach_target      = true
      targets = [
        {
          type                  = "lambda"
          target_group_name     = "${local.parameter}-tg"
          target_name           = "${local.parameter}-get-booking-func"
          target_port           = 8080
        },
      ]
    },
  }
}

locals {
  lambdas = {
    "${local.parameter}-get-booking-func" = {
      tags = {Name = "${local.parameter}-get-booking-func"}

      enable_lambda_edge = false
      enable_upload_zip  = false

      handler            = "lambda_function.lambda_handler"
      timeout            = 180
      runtime            = "python3.14"
      source_file_path   = "/lambda/lambda_function.py"
      output_file_path   = "/lambda/lambda_function_payload.zip"
      publish            = false

      enable_kms         = true
      kms_key_name       = "${local.parameter}-kms-platform" 
      
      enable_lambda_function_url = false
      lambda_function_url_auth_type = "NONE" # NONE, AWS_IAM

      iam_role_name      = "${local.parameter}-get-booking-func-role"
      iam_role_tags      = {Name = "${local.parameter}-get-booking-func-role"}

      enable_managed_policy = false
      iam_policies       = ["arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"]

      enable_custom_policy = true
      policy_name = "${local.parameter}-get-booking-func-policy"
      policy_tags = {Name = "${local.parameter}-get-booking-func-policy"}
      custom_policy_statements = [
        {
          effect    = "Allow"
          actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/get-booking:*"]
          conditions = []
        },
        {
          effect    = "Allow"
          actions   = ["dynamodb:GetItem", "dynamodb:Query"]
          resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-concert-db"]
          conditions = []
        },
        {
          effect    = "Allow"
          actions   = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets", "ec2:DeleteNetworkInterface", "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"]
          resources = ["*"]
          conditions = []
        },
      ]

      enable_environment = false
      environment_variables = {"TABLE_NAME" = "${local.parameter}-concert-db"}

      enable_logging = true
      cloudwatch_logs_group_name = "/${local.parameter}/lambda/get-booking"
      log_format = "Text" #, JSON
      application_log_format = "INFO" # TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
      system_log_format = "WARN" # DEBUG, INFO, WARN.

      enable_vpc_config = true
      vpc_name = "${local.parameter}-vpc"
      internal = true
      security_group_name = "${local.parameter}-lambda-sg"
      security_group_tags = {Name = "${local.parameter}-lambda-sg"}
      ingress_ports = []
      egress_ports = [{ from_port = 443, to_port = 443, protocol = "tcp", cidr_block = "0.0.0.0/0"},]
    }
  }
}

locals {
  s3s = {
    "${local.parameter}-web-${data.aws_caller_identity.current.account_id}" = {
      tags = {Name = "${local.parameter}-web-${data.aws_caller_identity.current.account_id}"}

      kms_key_name = "${local.parameter}-kms-data"
      enable_objects = true
      enable_object_kms = true
      objects = [
        {key = "index.html", source = "s3/index.html"},
        {key = "main.jpeg", source = "s3/main.jpeg"}
      ]

      block_public_access     = true
      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true

      enable_versioning       = true
    },
  }
}

locals {
  cloudfronts = {
    "${local.parameter}-svc-cf" = {
      tags = {Name = "${local.parameter}-svc-cf"}
      s3_bucket_name = "${local.parameter}-web-${data.aws_caller_identity.current.account_id}"

      enable_waf = true
      waf_name = "${local.parameter}-waf"

      origin_path = null
      default_root_object = "index.html"
    }
  }
}

locals {
  cloudwatch_logs = {
    "/${local.parameter}/vpc/flow-log" = {
      tags = {Name = "/${local.parameter}/vpc/flow-log"}

      enable_kms = true
      kms_key_name = "${local.parameter}-kms-platform"

      retention_in_days = 7

      create_log_stream = true
      log_stream_names = ["/${local.parameter}/flow-log/stream"]

      create_metric_filter = false
      metric_filters = [
        {
          name = "request-count"
          pattern = "{ $.method = \"POST\" }"

          metric_transformation = {
            name          = "app/RequestCount"
            namespace     = "${local.parameter}-metrics"
            value         = "1"
            default_value = "0"
            unit          = "Count"
            dimensions    = {}
          }
        },
      ]
    },
    "/${local.parameter}/lambda/get-booking" = {
      tags = {Name = "/${local.parameter}/lambda/get-booking"}

      enable_kms = true
      kms_key_name = "${local.parameter}-kms-platform"

      retention_in_days = 7

      create_log_stream = false
      log_stream_names = ["/${local.parameter}/lambda/get-booking"]

      create_metric_filter = false
      metric_filters = [
        {
          name = "request-count"
          pattern = "{ $.method = \"POST\" }"

          metric_transformation = {
            name          = "app/RequestCount"
            namespace     = "${local.parameter}-metrics"
            value         = "1"
            default_value = "0"
            unit          = "Count"
            dimensions    = {}
          }
        },
      ]
    },
    "/${local.parameter}/eks/book-app" = {
      tags = {Name = "/${local.parameter}/eks/book-app"}
      
      enable_kms = true
      kms_key_name = "${local.parameter}-kms-platform"

      retention_in_days = 7

      create_log_stream = false
      log_stream_names = ["/${local.parameter}/eks/book-app"]

      create_metric_filter = false
      metric_filters = [
        {
          name = "request-count"
          pattern = "{ $.method = \"POST\" }"

          metric_transformation = {
            name          = "app/RequestCount"
            namespace     = "${local.parameter}-metrics"
            value         = "1"
            default_value = "0"
            unit          = "Count"
            dimensions    = {}
          }
        },
      ]
    },
    "aws-waf-logs-${local.parameter}" = {
      tags = {Name = "aws-waf-logs-${local.parameter}"}

      enable_kms = true
      kms_key_name = "${local.parameter}-kms-platform"

      retention_in_days = 7

      create_log_stream = false
      log_stream_names = ["/${local.parameter}/waf/log/stream"]

      create_metric_filter = false
      metric_filters = [
        {
          name = "request-count"
          pattern = "{ $.method = \"POST\" }"

          metric_transformation = {
            name          = "app/RequestCount"
            namespace     = "${local.parameter}-metrics"
            value         = "1"
            default_value = "0"
            unit          = "Count"
            dimensions    = {}
          }
        },
      ]
    },
  }
}

locals {
  wafs = {
    "${local.parameter}-waf" = {
      tags = {Name = "${local.parameter}-waf"}
      metric_name = "${local.parameter}-waf"

      enable_cloudfront = true
      alb_name = "${local.parameter}-app-alb"

      enable_logging = true
      cloudwatch_logs_group_name = "aws-waf-logs-${local.parameter }"   

      default_action = "allow"
      default_block_response = 403 # 403, 404, 405
      custom_response_key  = "custom-block-response"
      custom_response_body = "Request blocked by Unicorn WAF"
      
      enable_managed = true
      managed_rules = [
        {
          enabled    = true
          name       = "AWSanagedRulesCommonRuleSet"
          priority   = 2
          vendor     = "AWS"
          rule_group = "AWSManagedRulesCommonRuleSet"
        },
        {
          enabled    = false
          name       = "AWSManagedRulesSQLiRuleSet"
          priority   = 2
          vendor     = "AWS"
          rule_group = "AWSManagedRulesSQLiRuleSet"
        },
        {
          enabled    = true
          name       = "AWSManagedRulesKnownBadInputsRuleSet"
          priority   = 3
          vendor     = "AWS"
          rule_group = "AWSManagedRulesKnownBadInputsRuleSet"
        }
      ]

      enable_custom = true
      custom_rules = [
        {
          enabled                  = true
          name                     = "unicorn-rate-limit"
          priority                 = 1
          action                   = "block"
          type                     = "RATE_BASED"
          limit                    = 50
          evaluation_window_sec    = 60
          aggregate_key            = "IP"
          enable_custom_response   = true
          custom_response_code     = 403
          custom_response_body_key = "custom-block-response"
          statements               = []
          
        }
      ]
    }
  }
}