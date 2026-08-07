variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "handler" {
  type = string
}

variable "timeout" {
  type = number
}

variable "runtime" {
  type = string
}

variable "publish" {
  type = bool
}

variable "kms_key_arn" {
  type = string
}

variable "enable_lambda_edge" {
  type = bool
}

variable "enable_upload_zip" {
  type = bool
}

variable "iam_role_name" {
  type  = string
}

variable "iam_role_tags" {
  type = map(string)
}

variable "enable_managed_policy" {
  type = bool
  default = false
}

variable "enable_custom_policy" {
  type = bool
  default = false
}

variable "policy_name" {
  type = string
}

variable "policy_tags" {
  type = map(string)
}

variable "statements" {
  type = list(object({
    sid       = optional(string)
    effect    = string
    actions   = list(string)
    resources = list(string)
    
    conditions = optional(list(object({
      test       = string
      variable   = string
      values     = list(string)
    })), [])
  }))
}

variable "iam_policies" {
  type  = list(string)
}

variable "source_file_path" {
  type = string
}

variable "output_file_path" {
  type = string
}

variable "enable_logging" {
  type = bool
  default = false
}

variable "log_group_name" {
  type = string
}

variable "log_format" {
  type = string
}

variable "application_log_format" {
  type = string
}

variable "system_log_format" {
  type = string
}

variable "enable_vpc_config" {
  type = bool
  default = false
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_name" {
  type  = string
}

variable "security_group_tags" {
  type = map(string)
}

variable "ingress_ports" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_block  = string
  }))
}

variable "egress_ports" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_block  = string
  }))
}