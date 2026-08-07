variable "project" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_id" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "keypair_name" { type = string }
variable "instance_name" { type = string }
variable "instance_profile_name" { type = string }
variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
