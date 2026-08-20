variable "project" {
  type        = string
}

variable "region" {
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  type        = string
}

variable "namespace" {
  type        = string
}

variable "ingress_name" {
  type        = string
}

variable "alb_arn_suffix" {
  type        = string
}

variable "rds_id" {
  type        = string
}