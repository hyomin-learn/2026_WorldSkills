variable "project" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "docdb_host" {
  type = string
}
