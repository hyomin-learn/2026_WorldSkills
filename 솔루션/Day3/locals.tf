locals {
  player_number = "000"

  parameter = "apdev"

  az_override  = ["a", "c"]

  azs = [
    for az in data.aws_availability_zones.az.names :
    az if contains(local.az_override, substr(az, -1, 1))
  ]
}

locals {
  security_groups = {
    "${local.parameter}-app-alb-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-app-alb-sg"
      security_group_tags = {Name = "${local.parameter}-app-alb-sg"}
      ingress_ports = [{from_port = 80, to_port = 80, protocol = "tcp", prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront.id}]
      egress_ports = [{from_port = 8080, to_port = 8080, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
    },
    "${local.parameter}-monitoring-alb-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-monitoring-alb-sg"
      security_group_tags = {Name = "${local.parameter}-monitoring-alb-sg"}
      ingress_ports = [{from_port = 80, to_port = 80, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
      egress_ports = [
        {from_port = 3000, to_port = 3000, protocol = "tcp", cidr_block = "0.0.0.0/0"},
        {from_port = 9090, to_port = 9090, protocol = "tcp", cidr_block = "0.0.0.0/0"}
      ]
    },
    "${local.parameter}-monitoring-alb-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-monitoring-alb-sg"
      security_group_tags = {Name = "${local.parameter}-monitoring-alb-sg"}
      ingress_ports = [{from_port = 80, to_port = 80, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
      egress_ports = [
        {from_port = 3000, to_port = 3000, protocol = "tcp", cidr_block = "0.0.0.0/0"},
        {from_port = 9090, to_port = 9090, protocol = "tcp", cidr_block = "0.0.0.0/0"}
      ]
    },
    "${local.parameter}-eks-app-node-sg" = {
      vpc_name = "${local.parameter}-vpc"

      security_group_name = "${local.parameter}-eks-app-node-sg"
      security_group_tags = {Name = "${local.parameter}-eks-app-node-sg"}
      ingress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
      egress_ports = [{from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"}]
    },
  }
}


locals {
  ec2s = {
    "${local.parameter}-bastion" = {
      vpc_name                = "${local.parameter}-vpc"
      subnet_name             = "${local.parameter}-public-a"

      instance_tags           = {Name = "${local.parameter}-bastion"}
      
      instance_type           = "t3.medium"
      userdata                = "/ec2/bastion/userdata.sh"
      
      enable_public_ip        = true
      enable_eip              = true
      eip_tags                = {Name = "${local.parameter}-bastion-eip"}

      root_block_device = {
        volume_size           = 30
        volume_type           = "gp3"
        delete_on_termination = true
      }

      security_group_name     = "${local.parameter}-bastion-sg"
      security_group_tags     = {Name = "${local.parameter}-bastion-sg"}
      ingress_ports = [
        {from_port = 22, to_port = 22, protocol = "tcp", cidr_block = "0.0.0.0/0"},
      ]

      egress_ports = [
        {from_port = 22, to_port = 22, protocol = "tcp", cidr_block = "0.0.0.0/0"},
        {from_port = 80, to_port = 80, protocol = "tcp", cidr_block = "0.0.0.0/0"},
        {from_port = 443, to_port = 443, protocol = "tcp", cidr_block = "0.0.0.0/0"},
        {from_port = 3306, to_port = 3306, protocol = "tcp", cidr_block = "0.0.0.0/0"},
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
    "${local.parameter}-user-ecr" = {
      tags = {Name = "${local.parameter}-user-ecr"}

      image_tag_mutability              = "IMMUTABLE" # IMMUTABLE or MUTABLE
      force_delete                      = true
      scan_images_on_push               = true

      enable_kms                        = false
      kms_key_name                      = "${local.parameter}/kms/ecr"
      encryption_type                   = "KMS"

      enable_image_tag_exclusion_filter = false
      image_tag_exclusion_filter = [
        {filter = "latest", filter_type = "WILDCARD"},
      ]
    },
    "${local.parameter}-product-ecr" = {
      tags = {Name = "${local.parameter}-product-ecr"}

      image_tag_mutability              = "IMMUTABLE" # IMMUTABLE or MUTABLE
      force_delete                      = true
      scan_images_on_push               = true

      enable_kms                        = false
      kms_key_name                      = "${local.parameter}/kms/ecr"
      encryption_type                   = "KMS"

      enable_image_tag_exclusion_filter = false
      image_tag_exclusion_filter = [
        {filter = "latest", filter_type = "WILDCARD"},
      ]
    },
    "${local.parameter}-stress-ecr" = {
      tags = {Name = "${local.parameter}-stress-ecr"}

      image_tag_mutability              = "IMMUTABLE" # IMMUTABLE or MUTABLE
      force_delete                      = true
      scan_images_on_push               = true

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
  rdss = {
    "${local.parameter}-rds-instance" = {
      vpc_name = "${local.parameter}-vpc"

      instance_tags = {Name = "${local.parameter}-rds-instance"}

      db_name                         = "${local.parameter}"
      class                           = "db.t3.micro"
      storage_type                    = "gp3"
      engine                          = "mysql"
      engine_version                  = "8.0"
      user_name                       = "admin"
      user_password                   = "Skill53##"
      port                            = 3306
      allocated_storage               = 20
      skip_final_snapshot             = true
      multi_az                        = true
      storage_encrypted               = true
      publicly_accessible             = false

      subnet_group_name               = "${local.parameter}-rds-sg"
      subnet_group_tags               = {Name = "${local.parameter}-rds-sg"}

      option_group_name               = "${local.parameter}-rds-og"
      option_group_engine             = "mysql"
      option_group_engine_version     = "8.0"
      option_group_tags               = {Name = "${local.parameter}-rds-og"}

      parameter_group_name            = "${local.parameter}-rds-pg"
      parameter_group_family          = "mysql8.0"
      parameter_group_tags            = {Name = "${local.parameter}-rds-pg"}

      security_group_name             = "${local.parameter}-rds-sg"
      security_group_tags             = {Name = "${local.parameter}-rds-sg"}

      ingress_ports = [{ from_port = 3306, to_port = 3306, protocol = "tcp", cidr_block = "0.0.0.0/0"},]

      egress_ports = [{ from_port = 0, to_port = 0, protocol = "-1", cidr_block = "0.0.0.0/0"},]
    }
  }
}

locals {
  rds_proxys = {
    "${local.parameter}-rds-proxy" = {
      vpc_name = "${local.parameter}-vpc"
      tags = {Name = "${local.parameter}-rds-proxy"}

      enable_db_cluster = false
      db_cluster_name   = "${local.parameter}-db-cluster"

      enable_db_instance = true
      db_instance_name   = "${local.parameter}-rds-instance"

      debug_logging = true
      engine_family = "MYSQL" # POSTGRESQL
      idle_client_timeout = 1800
      require_tls = false

      secrets_manager_name = "${local.parameter}-rds-secrets"

      connection_borrow_timeout = 30
      max_connections_percent = 100
      max_idle_connections_percent = 90

      security_group_name = "${local.parameter}-rds-proxy-sg"
      security_group_tags = {Name = "${local.parameter}-rds-proxy-sg"}
      ingress_ports = [{from_port = 3306, to_port = 3306, protocol = "tcp", cidr_block = "0.0.0.0/0"}]
      egress_ports = [{from_port = 3306, to_port = 3306, protocol = "tcp", cidr_block = "0.0.0.0/0"}]

      role_name = "${local.parameter}-rds-proxy-role"
      role_tags = {Name = "${local.parameter}-rds-proxy-role"}
      service_name = "rds"

      role_statements = [
        {
          effect    = "Allow"
          principals = {type = "Service", identifiers = ["rds.amazonaws.com"]}
          actions   = ["sts:AssumeRole"]
          resources = []
          conditions = []
        }
      ]
      
      policy_statements = [
        {
          effect    = "Allow"
          actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
          resources = ["*"]
          conditions = []
        },
        {
          effect    = "Allow"
          actions   = ["rds-db:connect"]
          resources = ["*"]
          conditions = []
        },
        {
          effect    = "Allow"
          actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
          resources = ["*"]
          conditions = []
        }
      ]

      enable_custom_policy = true
      policy_name          = "${local.parameter}-rds-proxy-policy"
      policy_tags = {Name = "${local.parameter}-rds-proxy-policy"}

      enable_managed_policy = false
      managed_policy_arns   = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
  }
}

locals {
  secrets_managers = {
    "${local.parameter}-rds-secrets" = {
      tags = {Name = "${local.parameter}-rds-secrets"}
      
      rds_name      = "${local.parameter}-rds-instance"
      enable_values = false
    },
    "${local.parameter}-rds-proxy-secrets" = {
      tags = {Name = "${local.parameter}-rds-proxy-secrets"}
      
      rds_name      = "${local.parameter}-rds-instance"
      rds_proxy_name = "${local.parameter}-rds-proxy"
      enable_values = false
    },
  }
}

locals {
  s3s = {
    "${local.parameter}-static-${data.aws_caller_identity.current.account_id}" = {
      tags = {Name = "${local.parameter}-static-${data.aws_caller_identity.current.account_id}"}

      kms_key_name = "${local.parameter}-kms-data"
      enable_objects = false
      enable_object_kms = false
      objects = [
        {key = "index.html", source = "s3/index.html"},
        {key = "main.jpeg", source = "s3/main.jpeg"}
      ]

      block_public_access     = false
      block_public_acls       = false
      block_public_policy     = false
      ignore_public_acls      = false
      restrict_public_buckets = false

      enable_versioning       = false
    },
    "${local.parameter}-logs-${data.aws_caller_identity.current.account_id}" = {
      tags = {Name = "${local.parameter}-logs-${data.aws_caller_identity.current.account_id}"}

      kms_key_name = "${local.parameter}-kms-data"
      enable_objects = false
      enable_object_kms = false
      objects = [
        {key = "index.html", source = "s3/index.html"},
        {key = "main.jpeg", source = "s3/main.jpeg"}
      ]

      block_public_access     = false
      block_public_acls       = false
      block_public_policy     = false
      ignore_public_acls      = false
      restrict_public_buckets = false

      enable_versioning       = false
    },
  }
}

locals {
  cloudfronts = {
    "${local.parameter}-cdn" = {
      tags = {Name = "${local.parameter}-cdn"}
      s3_bucket_name = "${local.parameter}-static-${data.aws_caller_identity.current.account_id}"

      origin_path = null
      default_root_object = null

      enable_waf = true
      waf_name = "${local.parameter}-waf"

      enable_cloudfront_function = true
      cloudfront_function_name = "${local.parameter}-cdn-function"
      cloudfront_function_runtime = "cloudfront-js-2.0"
      cloudfront_function_publish = true
      cloudfront_function_code_path = "/cloudfront/index.js"

      enable_access_logs = true
      logging_config ={
        s3_bucket_name = "${local.parameter}-logs-${data.aws_caller_identity.current.account_id}"
        include_cookies = false
        prefix = "cf-logs/"
      }
    }
  }
}

locals {
  wafs = {
    "${local.parameter}-waf" = {
      tags = {
        Name = "${local.parameter}-waf"
      }

      metric_name = "${local.parameter}-waf"

      enable_cloudfront = true
      alb_name          = "${local.parameter}-app-alb"

      enable_logging             = false
      cloudwatch_logs_group_name = "aws-waf-logs-${local.parameter}"

      default_action         = "block"
      default_block_response = 404
      custom_response_key    = "custom-block-response"
      custom_response_body   = "Not Found"

      enable_managed = true

      managed_rules = [
        {
          enabled    = true
          name       = "AWSManagedRulesCommonRuleSet"
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
          enabled    = true
          name       = "AWSManagedRulesKnownBadInputsRuleSet"
          priority   = 3
          vendor     = "AWS"
          rule_group = "AWSManagedRulesKnownBadInputsRuleSet"
        }
      ]

      enable_custom = true

      custom_rules = [
        # 1. POST /v1/user
        {
          enabled  = true
          name     = "allow-user-post"
          priority = 110
          type     = "AND"
          action   = "allow"

          statements = [
            {
              field                 = "method"
              search_string         = "POST"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "uri_path"
              search_string         = "/v1/user"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "requestid"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "uuid"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "username"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "email"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            }
          ]
        },

        # 2. GET /v1/user
        {
          enabled  = true
          name     = "allow-user-get"
          priority = 111
          type     = "AND"
          action   = "allow"

          statements = [
            {
              field                 = "method"
              search_string         = "GET"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "uri_path"
              search_string         = "/v1/user"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "query_string"
              search_string         = "email="
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "query_string"
              search_string         = "requestid="
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "query_string"
              search_string         = "uuid="
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            }
          ]
        },

        # 3. POST /v1/product
        {
          enabled  = true
          name     = "allow-product-post"
          priority = 112
          type     = "AND"
          action   = "allow"

          statements = [
            {
              field                 = "method"
              search_string         = "POST"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "uri_path"
              search_string         = "/v1/product"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "requestid"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "uuid"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "id"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "name"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "price"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            }
          ]
        },

        # 4. GET /v1/product
        {
          enabled  = true
          name     = "allow-product-get"
          priority = 113
          type     = "AND"
          action   = "allow"

          statements = [
            {
              field                 = "method"
              search_string         = "GET"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "uri_path"
              search_string         = "/v1/product"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "query_string"
              search_string         = "id="
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "query_string"
              search_string         = "requestid="
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "query_string"
              search_string         = "uuid="
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            }
          ]
        },

        # 5. PUT /v1/product - JSON 요청
        {
          enabled  = true
          name     = "allow-product-put"
          priority = 114
          type     = "AND"
          action   = "allow"

          statements = [
            {
              field                 = "method"
              search_string         = "PUT"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "uri_path"
              search_string         = "/v1/product"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "requestid"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "uuid"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "id"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            }
          ]
        },

        # 6. PUT /v1/product - Image 요청
        {
          enabled  = true
          name     = "allow-product-put-image"
          priority = 115
          type     = "AND"
          action   = "allow"

          statements = [
            {
              field                 = "method"
              search_string         = "PUT"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "uri_path"
              search_string         = "/v1/product"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "body"
              search_string         = "requestId"
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "body"
              search_string         = "uuid"
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "body"
              search_string         = "id"
              positional_constraint = "CONTAINS"
              limit                 = null
              aggregate_key         = null
            }
          ]
        },

        # 7. POST /v1/stress
        {
          enabled  = true
          name     = "allow-stress-post"
          priority = 116
          type     = "AND"
          action   = "allow"

          statements = [
            {
              field                 = "method"
              search_string         = "POST"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "uri_path"
              search_string         = "/v1/stress"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "requestid"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "uuid"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            },
            {
              field                 = "json_body"
              search_string         = "length"
              positional_constraint = "EXACTLY"
              limit                 = null
              aggregate_key         = null
            }
          ]
        }
      ]
    }
  }
}

locals {
  db_username = "admin"
  db_password = "Skill53##"
}