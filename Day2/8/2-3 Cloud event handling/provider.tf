terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    tls = {
      source = "hashicorp/tls"
      version = "4.2.1"
    }

    local = {
      source = "hashicorp/local"
      version = "2.7.0"
    }

    archive = {
      source = "hashicorp/archive"
      version = "2.7.1"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
  profile = "default"
}

provider "tls" {}

provider "local" {}

provider "archive" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "az" {state = "available"}