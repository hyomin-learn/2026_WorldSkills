variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "keypair_name" {
  description = "EC2 Key Pair Name"
  type        = string
}

variable "instance_name" {
  description = "App instance Name tag"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "public_subnet_id" {
  description = "Public subnet ID to launch the app EC2 into"
  type        = string
}

variable "app_sg_id" {
  description = "Security Group ID for the app EC2 (from vpc module)"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name (from iam module)"
  type        = string
}

# ---- Application environment variables ----
variable "aws_region" {
  description = "AWS region passed to the app (AWS_REGION)"
  type        = string
}

variable "table_name" {
  description = "Reservation table name (TABLE_NAME)"
  type        = string
}

variable "gsi_name" {
  description = "GSI name (GSI_NAME)"
  type        = string
}
