variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "skills-nosql"
}

variable "vpc_cidr" {
  type    = string
  default = "10.50.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.50.1.0/24"
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.50.11.0/24", "10.50.12.0/24"]
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2b"]
}

variable "docdb_master_username" {
  description = "DocumentDB master username"
  type        = string
  default     = "skillsadmin"
}

variable "docdb_master_password" {
  description = "DocumentDB master password."
  type        = string
  sensitive   = true
  default     = "zjawjd123"

  validation {
    condition     = length(var.docdb_master_password) >= 8 && !can(regex("[/@\"]", var.docdb_master_password))
    error_message = "비밀번호는 8자 이상이어야 하며 '/', '@', '\"' 문자를 포함할 수 없습니다."
  }
}

variable "docdb_instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "docdb_backup_retention_period" {
  type    = number
  default = 7
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ec2_key_name" {
  description = "Existing EC2 key pair name for SSH access (optional, leave empty to skip)"
  type        = string
  default     = ""
}

variable "docdb_client_py_path" {
  type    = string
  default = "./files/docdb_client.py"
}

variable "retail_dataset_json_path" {
  type    = string
  default = "./files/retail_dataset.json"
}
