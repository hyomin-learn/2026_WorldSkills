variable "vpc_id" {
  type = string
}

variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "log_destination_type" {
  type = string
}

variable "log_destination_arn" {
  type = string
}

variable "log_format" {
  type = string
}

variable "traffic_type" {
  type    = string
}

variable "enable_iam_role" {
  type = bool
}

variable "iam_role_name" {
  type = string
}

variable "iam_role_tags" {
  type = map(string)
}

variable "statements" {
  type = list(object({
    sid        = optional(string, null)
    effect     = string
    actions    = list(string)
    resources  = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}

variable "policy_name" {
  type    = string
}

variable "policy_tags" {
  type    = map(string)
}