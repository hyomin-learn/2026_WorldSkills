variable "service_network_auth_type" {
  type = string
}

variable "client_assoc_sg_id" {
  type        = string
}

variable "lattice_service_instance_id" {
  type = string
}

variable "vpc_ids" {
  type        = map(string)
}