terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# =========================== 3. Network Configuration ===========================
module "vpc" {
  source  = "./modules/vpc"
  project = var.project
}

# =========================== IAM (bastion role) ===========================
module "iam" {
  source        = "./modules/iam"
  instance_name = "${var.project}-bastion"
}

# =========================== 관리(작업)용 Bastion (wskorea26-vpc 퍼블릭 서브넷 배치) ===========================
# 같은 VPC 내부이므로 EKS Private API 엔드포인트에 접근 가능. 채점 전 destroy 권장.
module "mgmt" {
  source = "./modules/mgmt"

  project                = var.project
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids["c"]
  instance_name           = "${var.project}-bastion"
  keypair_name            = var.key_pair_name
  instance_type           = "t3.small"
  instance_profile_name   = module.iam.instance_profile_name
  allowed_ssh_cidr         = var.allowed_ssh_cidr
}

# =========================== 6. Elastic Container Registry ===========================
module "ecr" {
  source  = "./modules/ecr"
  project = var.project
}

# =========================== 7. NoSQL Database ===========================
module "dynamodb" {
  source  = "./modules/dynamodb"
  project = var.project
}

# =========================== 8. EKS Secret 암호화용 KMS ===========================
module "eks_kms" {
  source  = "./modules/eks-kms"
  project = var.project
}

# =========================== 4. Simple Storage Service ===========================
module "s3" {
  source      = "./modules/s3"
  project      = var.project
  exam_number  = var.exam_number
}

# =========================== 9. Lambda Function ===========================
module "lambda" {
  source = "./modules/lambda"

  project        = var.project
  table_name     = module.dynamodb.table_name
  table_arn      = module.dynamodb.table_arn
  gsi_name       = module.dynamodb.gsi_name
  db_kms_key_arn = module.dynamodb.db_kms_key_arn
}

# =========================== 10. Load Balancing : book ALB (+ Lambda 대상그룹) ===========================
module "book_alb" {
  source = "./modules/book-alb"

  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids_list
  alb_sg_id                = module.vpc.book_alb_sg_id
  lambda_function_name    = module.lambda.function_name
  lambda_function_arn     = module.lambda.function_arn
}

# =========================== 12. Monitoring : Grafana ALB ===========================
module "monitoring_alb" {
  source = "./modules/monitoring-alb"

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids_list
  alb_sg_id            = module.vpc.grafana_alb_sg_id
}

# =========================== 11. CloudFront ===========================
module "cloudfront" {
  source = "./modules/cloudfront"

  project                          = var.project
  s3_bucket_regional_domain_name   = module.s3.bucket_regional_domain_name
  alb_dns_name                      = module.book_alb.alb_dns_name
}

# S3 버킷 정책 : CloudFront(OAC) 를 통한 접근만 허용 (순환참조 방지를 위해 루트에서 부착)
data "aws_iam_policy_document" "s3_oac" {
  statement {
    sid       = "AllowCloudFrontOAC"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${module.s3.bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "concert_oac" {
  bucket = module.s3.bucket_name
  policy = data.aws_iam_policy_document.s3_oac.json
}

# =========================== 5/8/9/12. EKS 클러스터 + 애플리케이션 + 모니터링 배포 ===========================
module "eks" {
  source = "./modules/eks"

  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  eks_key_arn              = module.eks_kms.eks_kms_key_arn
  node_extra_sg_id         = module.vpc.node_extra_sg_id
  vpc_environment_sg_id    = module.vpc.vpc_environment_sg_id

  bastion_instance_id      = module.mgmt.bastion_instance_id
  bastion_public_ip        = module.mgmt.bastion_public_ip
  bastion_sg_id            = module.mgmt.bastion_sg_id
  bastion_private_key_pem  = module.mgmt.bastion_private_key_pem

  ecr_repo_url   = module.ecr.repository_url
  ecr_repo_name  = module.ecr.repository_name

  table_name              = module.dynamodb.table_name
  book_write_policy_arn   = module.dynamodb.book_write_policy_arn

  book_target_group_arn     = module.book_alb.book_target_group_arn
  book_node_port             = module.book_alb.node_port
  grafana_target_group_arn  = module.monitoring_alb.target_group_arn
  grafana_node_port          = module.monitoring_alb.node_port

  grafana_admin_user     = "skills-${var.exam_number}-admin"
  grafana_admin_password = var.grafana_admin_password

  depends_on = [
    module.ecr,
    module.dynamodb,
    module.eks_kms,
    module.book_alb,
    module.monitoring_alb,
    module.cloudfront,
  ]
}
