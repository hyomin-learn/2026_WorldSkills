variable "ec2_instance_id" {
  type = string
}

variable "create" {
  type    = bool
  default = true
}

variable "region" {
  type = string
}

variable "bootstrap_brokers_iam" {
  type = string
}

variable "raw_topic_name" {
  type = string
}

variable "raw_topic_partitions" {
  type = number
}

variable "raw_topic_replication_factor" {
  type = number
}

variable "alert_topic_name" {
  type = string
}

variable "alert_topic_partitions" {
  type = number
}

variable "alert_topic_replication_factor" {
  type = number
}
