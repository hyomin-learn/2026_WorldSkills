variable "project" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "kafka_version" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "broker_count" {
  type = number
}

variable "security_group_id" {
  type = string
}
