variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = map(string) } # {c=..., d=...}
variable "eks_key_arn" { type = string }
variable "node_extra_sg_id" { type = string }
variable "vpc_environment_sg_id" { type = string }

variable "bastion_instance_id" { type = string }
variable "bastion_public_ip" { type = string }
variable "bastion_sg_id" { type = string }
variable "bastion_private_key_pem" {
  type      = string
  sensitive = true
}

variable "ecr_repo_url"  { type = string }
variable "ecr_repo_name" { type = string }

variable "table_name" { type = string }
variable "book_write_policy_arn" { type = string }

variable "book_target_group_arn"    { type = string }
variable "book_node_port"           { type = number }
variable "grafana_target_group_arn" { type = string }
variable "grafana_node_port"        { type = number }

variable "grafana_admin_user"     { type = string }
variable "grafana_admin_password" {
  type      = string
  sensitive = true
}
