variable "project" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "region" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "msk_cluster_arn" {
  type = string
}

variable "bootstrap_brokers_plaintext" {
  type = string
}

variable "raw_topic_name" {
  type = string
}

variable "app_bucket_name" {
  type = string
}

variable "app_object_key" {
  type = string
}
