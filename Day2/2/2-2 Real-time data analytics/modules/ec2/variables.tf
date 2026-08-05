variable "project" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB (analytics-pub-a, analytics-pub-b)"
  type        = list(string)
}

variable "private_subnet_id" {
  description = "Private subnet for the EC2 instance"
  type        = string
}

variable "alb_sg_id" {
  type = string
}

variable "ec2_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "stream_name" {
  description = "Kinesis stream name passed to the app as STREAM_NAME"
  type        = string
}

variable "aws_region" {
  description = "Region passed to the app as AWS_REGION"
  type        = string
  default     = "ap-northeast-2"
}

variable "app_port" {
  description = "Port the Flask/Gunicorn app listens on (Application.md => 5000)"
  type        = number
  default     = 5000
}
