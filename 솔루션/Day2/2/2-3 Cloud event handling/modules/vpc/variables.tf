variable "project" {
  type = string
}

variable "vpc_cidr" {
  description = "event-vpc CIDR block"
  type        = string
  default     = "172.16.0.0/16"
}

variable "availability_zones" {
  description = "AZs for event-pub-a / event-pub-b"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}
