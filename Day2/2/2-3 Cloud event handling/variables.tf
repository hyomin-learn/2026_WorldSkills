variable "project" {
  description = "Project name prefix (wsc2026)"
  type        = string
  default     = "wsc2026"
}

variable "region" {
  description = "Region for Cloud Event Handling"
  type        = string
  default     = "eu-west-1"
}

variable "availability_zones" {
  description = "AZs for event-pub-a / event-pub-b"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "instance_type" {
  description = "Monitored EC2 instance type"
  type        = string
  default     = "t3.micro"
}
