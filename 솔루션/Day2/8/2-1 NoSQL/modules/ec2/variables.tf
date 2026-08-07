variable "project" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "client_security_group_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type    = string
  default = ""
}

variable "secret_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "app_bucket_name" {
  type = string
}

variable "app_bucket_arn" {
  type = string
}

variable "docdb_client_object_key" {
  type = string
}

variable "retail_dataset_object_key" {
  type = string
}
