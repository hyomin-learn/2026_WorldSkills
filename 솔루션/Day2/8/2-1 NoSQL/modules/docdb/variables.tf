variable "project" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "docdb_security_group_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "instance_class" {
  type = string
}

variable "backup_retention_period" {
  type = number
}
