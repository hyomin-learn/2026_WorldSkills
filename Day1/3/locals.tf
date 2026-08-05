locals {
  player_number = 101

  parameter = "wsc2026"

  az_override  = ["a", "b"]

  azs = [
    for az in data.aws_availability_zones.az.names :
    az if contains(local.az_override, substr(az, -1, 1))
  ]
}

locals {
  vpcs = {
    "${local.parameter}-skills-vpc" = {
      vpc_cidr         = "192.168.0.0/16"
      default_rtb_tags = null
      default_sg_tags  = {Name = "${local.parameter}-skills-default-sg"}

      vpc_tags = {Name = "${local.parameter}-skills-vpc"}

      enable_igw       = true
      enable_natgw     = true

      types = [
        {
          type         = "public"
          sn_cidrs     = ["192.168.1.0/24", "192.168.10.0/24"]
          sn_tags      = {Name = "${local.parameter}-skills-hub-sub-$1"}

          rtb_tags     = {Name = "${local.parameter}-skills-hub-rtb"}

          igw_tags     = {Name = "${local.parameter}-skills-igw"}
        },
        {
          type         = "private"
          sn_cidrs     = ["192.168.2.0/24", "192.168.20.0/24"]
          sn_tags      = {Name = "${local.parameter}-skills-app-sub-$1"}

          rtb_tags     = {Name = "${local.parameter}-skills-app-rtb-$1"}

          natgw_tags   = {Name = "${local.parameter}-skills-nat-$1"}
        },
      ]
    }
  }
}

locals {
  security_groups = {
    "${local.parameter}-eks-control-plane-sg" = {
      vpc_name = "${local.parameter}-skills-vpc"

      security_group_name = "${local.parameter}-eks-control-plane-sg"
      security_group_tags = {Name = "${local.parameter}-eks-control-plane-sg"}
      ingress_ports = [{from_port = 443, to_port = 443, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
      egress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
    },
    "${local.parameter}-app-alb-sg" = {
      vpc_name = "${local.parameter}-skills-vpc"

      security_group_name = "${local.parameter}-app-alb-sg"
      security_group_tags = {Name = "${local.parameter}-app-alb-sg"}
      ingress_ports = [{from_port = 80, to_port = 80, protocol = "tcp", prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront.id}]
      egress_ports = [{from_port = 8080, to_port = 8080, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
    },
    "mark-sg" = {
      vpc_name = "${local.parameter}-skills-vpc"

      security_group_name = "mark-sg"
      security_group_tags = {Name = "mark-sg"}
      ingress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
      egress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
    },
  }
}

locals {
  ec2s = {
    "${local.parameter}-bastion" = {
      vpc_name                = "${local.parameter}-skills-vpc"
      subnet_name             = "${local.parameter}-skills-hub-sub-a"

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
    "${local.parameter}-eks-kms" = {
      tags = {Name = "${local.parameter}-eks-kms"}
      
      alias_name              = "alias/${local.parameter}-eks-kms"
      key_usage               = "ENCRYPT_DECRYPT"
      deletion_window_in_days = 7
      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["*"]}
          actions = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*"]
          resources = ["*"]
          conditions = [{test = "StringEquals", variable = "aws:PrincipalAccount", values = ["${data.aws_caller_identity.current.account_id}"]}]
        },
      ]
    },
    "${local.parameter}-ecr-kms" = {
      tags = {Name = "${local.parameter}-ecr-kms"}
      
      alias_name              = "alias/${local.parameter}-ecr-kms"
      key_usage               = "ENCRYPT_DECRYPT"
      deletion_window_in_days = 7
      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["*"]}
          actions = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*"]
          resources = ["*"]
          conditions = [{test = "StringEquals", variable = "aws:PrincipalAccount", values = ["${data.aws_caller_identity.current.account_id}"]}]
        },
      ]
    },
    "${local.parameter}-bucket-kms" = {
      tags = {Name = "${local.parameter}-bucket-kms"}
      
      alias_name              = "alias/${local.parameter}-bucket-kms"
      key_usage               = "ENCRYPT_DECRYPT"
      deletion_window_in_days = 7
      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["*"]}
          actions = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*"]
          resources = ["*"]
          conditions = [{test = "StringEquals", variable = "aws:PrincipalAccount", values = ["${data.aws_caller_identity.current.account_id}"]}]
        },
        {
          effect = "Allow"
          principals = {type = "Service", identifiers = ["cloudfront.amazonaws.com"]}
          actions = ["kms:Decrypt", "kms:GenerateDataKey*"]
          resources = ["*"]
          conditions = []
        },
      ]
    },
    "${local.parameter}-db-kms" = {
      tags = {Name = "${local.parameter}-db-kms"}

      alias_name              = "alias/${local.parameter}-db-kms"
      key_usage               = "ENCRYPT_DECRYPT"
      deletion_window_in_days = 7
      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["*"]}
          actions = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*"]
          resources = ["*"]
          conditions = [{test = "StringEquals", variable = "aws:PrincipalAccount", values = ["${data.aws_caller_identity.current.account_id}"]}]
        },
      ]
    },
    "${local.parameter}-function-kms" = {
      tags = {Name = "${local.parameter}-function-kms"}

      alias_name              = "alias/${local.parameter}-function-kms"
      key_usage               = "ENCRYPT_DECRYPT"
      deletion_window_in_days = 7
      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["*"]}
          actions = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*"]
          resources = ["*"]
          conditions = [{test = "StringEquals", variable = "aws:PrincipalAccount", values = ["${data.aws_caller_identity.current.account_id}"]}]
        },
      ]
    },
  }
}

locals {
  iams = {
    "${local.parameter}-book-pod-role" = {
      role_tags = {Name = "${local.parameter}-book-pod-role"}
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
          resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-book-table"]
          conditions = []
        }
      ]

      enable_inline_policy  = false
      inline_policy_name    = "iam-inline-policy"

      enable_custom_policy = true
      policy_name          = "${local.parameter}-book-pod-policy"
      policy_tags = {Name = "${local.parameter}-book-pod-policy"}

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
          actions   = ["logs:CreateLogGroup"]
          resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"]
          conditions = []
        },
        {
          effect    = "Allow"
          actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
          resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*:*"]
          conditions = []
        }
      ]

      enable_inline_policy  = false
      inline_policy_name    = "iam-inline-policy"

      enable_custom_policy = true
      policy_name          = "${local.parameter}-fluent-bit-policy"
      policy_tags = {Name = "${local.parameter}-fluent-bit-policy"}

      enable_managed_policy = false
      managed_policy_arns   = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    },
    "${local.parameter}-grafana-role" = {
      role_tags = {Name = "${local.parameter}-grafana-role"}

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
          actions   = ["logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:GetLogEvents", "logs:GetLogRecord", "logs:FilterLogEvents", "logs:StartQuery", "logs:StopQuery", "logs:GetQueryResults", "logs:DescribeQueryDefinitions", "logs:GetLogGroupFields", "cloudwatch:ListMetrics", "cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics", "oam:ListSinks", "ec2:DescribeRegions"]
          resources = ["*"]
          conditions = []
        }
      ]

      enable_inline_policy  = false
      inline_policy_name    = "iam-inline-policy"

      enable_custom_policy = true
      policy_name          = "${local.parameter}-grafana-policy"
      policy_tags = {Name = "${local.parameter}-grafana-policy"}

      enable_managed_policy = false
      managed_policy_arns   = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    },
  }
}

locals {
  ecrs = {
    "${local.parameter}-book-ecr" = {
      tags = {Name = "${local.parameter}-book-ecr"}

      image_tag_mutability              = "MUTABLE_WITH_EXCLUSION"
      force_delete                      = true
      scan_images_on_push               = true

      enable_kms                        = true
      kms_key_name                      = "${local.parameter}-ecr-kms"
      encryption_type                   = "KMS"

      enable_image_tag_mutability_exclusion_filter = true
      image_tag_mutability_exclusion_filter = [
        {filter = "v1*", filter_type = "WILDCARD"},
      ]
    },
  }
}

locals {
  dynamodbs = {
    "${local.parameter}-book-table" = {
      tags = {Name = "${local.parameter}-book-table"}

      billing_mode   = "PAY_PER_REQUEST" # PROVISIONED
      read_capacity  = 20
      write_capacity = 20
      deletion_protection_enabled = true

      enable_kms    = true
      kms_key_name  = "${local.parameter}-db-kms"

      hash_key = "client_id"
      range_key = null

      attributes = [
        {name = "client_id", type = "S"},
        {name = "booking_id", type = "S"},
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
          name = "booking_id-index"
          hash_key = "booking_id"
          range_key = null
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
          kms_key_name = "${local.parameter}-db-kms"
          propagate_tags = null
          point_in_time_recovery = null
          consistency_mode = null
        },
      ]

      enable_resource_policy = true
      statements = [
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.parameter}-book-pod-role"]}
          actions = ["dynamodb:PutItem"]
          resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-book-table"]
          conditions = []
        },
        {
          effect = "Allow"
          principals = {type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.parameter}-book-function-role"]}
          actions = ["dynamodb:Query"]
          resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-book-table"]
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
  lambdas = {
    "${local.parameter}-book-get-function" = {
      tags = {Name = "${local.parameter}-book-get-function"}

      enable_lambda_edge = false
      enable_upload_zip  = false

      handler            = "lambda_function.lambda_handler"
      timeout            = 180
      runtime            = "python3.12"
      source_file_path   = "/lambda/lambda_function.py"
      output_file_path   = "/lambda/lambda_function_payload.zip"
      publish            = false

      enable_kms         = true
      kms_key_name       = "${local.parameter}-function-kms" 
      
      enable_lambda_function_url = true
      lambda_function_url_auth_type = "NONE" # NONE, AWS_IAM

      iam_role_name      = "${local.parameter}-book-function-role"
      iam_role_tags      = {Name = "${local.parameter}-book-function-role"}

      enable_managed_policy = false
      iam_policies       = ["arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"]

      enable_custom_policy = true
      policy_name = "${local.parameter}-book-function-policy"
      policy_tags = {Name = "${local.parameter}-book-function-policy"}
      custom_policy_statements = [
        {
          effect    = "Allow"
          actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"]
          conditions = []
        },
        {
          effect    = "Allow"
          actions   = ["dynamodb:GetItem", "dynamodb:Query"]
          resources = ["arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-book-table", "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.parameter}-book-table/index/booking_id-index"]
          conditions = []
        },
      ]
      
      enable_environment = true
      environment_variables = {"TABLE_NAME" = "${local.parameter}-book-table"}

      enable_logging = false
      cloudwatch_logs_group_name = "/${local.parameter}/lambda/get-booking"
      log_format = "Text" #, JSON
      application_log_format = "INFO" # TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
      system_log_format = "WARN" # DEBUG, INFO, WARN.

      enable_vpc_config = false
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
  cloudwatch_logs = {
    "/${local.parameter}/pod/log" = {
      tags = {Name = "/${local.parameter}/pod/log"}

      enable_kms = false
      kms_key_name = "${local.parameter}-kms-cw"

      retention_in_days = 7

      create_log_stream = false
      log_stream_names = ["/${local.parameter}/flow-log/stream"]

      create_metric_filter = true
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
        {
          name = "status-count"
          pattern = "{ $.status = * }"

          metric_transformation = {
            name          = "app/StatusCount"
            namespace     = "${local.parameter}-metrics"
            value         = "1"
            default_value = null
            unit          = "Count"
            dimensions    = {"StatusCode" = "$.status"}
          }
        },
      ]
    },
  }
}

locals {
  s3s = {
    "${local.parameter}-static-page-${local.player_number}-bucket" = {
      tags = {Name = "${local.parameter}-static-page-${local.player_number}-bucket"}
      
      enable_objects    = true
      objects = [
        { key = "static/index.html", source = "s3/index.html" },
        { key = "static/main.jpeg", source = "s3/main.jpeg" }
      ]

      enable_bucket_kms = true
      enable_object_kms = true
      server_side_encryption = "aws:kms" # aws:kms:dsse
      kms_key_name = "${local.parameter}-bucket-kms"
    },
  }
}

locals {
  cloudfronts = {
    "${local.parameter}-cdn" = {
      tags = {Name = "${local.parameter}-cdn"}
      s3_bucket_name = "${local.parameter}-static-page-${local.player_number}-bucket"
      lambda_name = "${local.parameter}-book-get-function"

      enable_waf = true
      waf_name = "${local.parameter}-waf"

      origin_path = "/static"
      default_root_object = "index.html"

      enable_cloudfront_function = true
      cloudfront_function_name = "${local.parameter}-cdn-function"
      cloudfront_function_runtime = "cloudfront-js-2.0"
      cloudfront_function_publish = true
      cloudfront_function_code_path = "/cloudfront/index.js"
    }
  }
}

locals {
  wafs = {
    "${local.parameter}-waf" = {
      tags = {Name = "${local.parameter}-waf"}
      metric_name = "${local.parameter}-waf"

      enable_cloudfront = true
      alb_name = "${local.parameter}-app-alb"

      enable_logging = false
      cloudwatch_logs_group_name = "/${local.parameter}/waf/log"

      default_action = "allow" # allow, block
      default_block_response = 404 # 403, 404, 405
      custom_response_body = "Not Found"

      enable_managed = true
      managed_rules = [
        {
          enabled    = true
          name       = "AWSanagedRulesCommonRuleSet"
          priority   = 1
          vendor     = "AWS"
          rule_group = "AWSManagedRulesCommonRuleSet"
        },
        {
          enabled    = true
          name       = "AWSManagedRulesSQLiRuleSet"
          priority   = 2
          vendor     = "AWS"
          rule_group = "AWSManagedRulesSQLiRuleSet"
        },
        {
          enabled    = false
          name       = "AWSManagedRulesKnownBadInputsRuleSet"
          priority   = 3
          vendor     = "AWS"
          rule_group = "AWSManagedRulesKnownBadInputsRuleSet"
        }
      ]

      enable_custom = true
      custom_rules = [
        {
          enabled       = true
          name          = "rate-limit-200-per-minutes"
          priority      = 100
          type          = "RATE_BASED"
          action        = "block"
          limit         = 200
          aggregate_key = "IP"
          evaluation_window_sec = 60
          statements    = []
        },
        # {
        #   enabled  = true
        #   name     = "block-delete-v1-book"
        #   priority = 110
        #   type     = "AND"
        #   action   = "block"
        #   statements = [
        #     {
        #       field                 = "method"
        #       search_string         = "DELETE"
        #       positional_constraint = "EXACTLY"
        #       limit                 = null
        #       aggregate_key         = null
        #     },
        #     {
        #       field                 = "uri_path"
        #       search_string         = "/v1/book"
        #       positional_constraint = "STARTS_WITH"
        #       limit                 = null
        #       aggregate_key         = null
        #     }
        #   ]
        # }
      ]
    }
  }
}