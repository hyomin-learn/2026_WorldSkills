variable "project" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet for the monitored EC2 (event-pub-a)"
  type        = string
}

variable "sg_id" {
  description = "Security group attached to the EC2 (wsc2026-event-sg)"
  type        = string
}
