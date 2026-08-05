variable "project" {
  type = string
}

variable "runtime" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "msk_cluster_arn" {
  type = string
}

variable "msk_bootstrap_brokers_iam" {
  type = string
}

variable "raw_topic_name" {
  type = string
}

variable "alert_topic_name" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}
