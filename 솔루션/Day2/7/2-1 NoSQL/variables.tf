variable "project" {
  description = "Project name prefix used across all resources"
  type        = string
  default     = "bigbae-nosql"
}

variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}
