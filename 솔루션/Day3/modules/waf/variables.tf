variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "metric_name" {
  type = string
}

variable "enable_cloudfront" {
  type = bool
  default = false
}

variable "alb_arn" {
  type    = string
  default = null
}

variable "default_action" {
  type    = string
}

variable "default_block_response" {
  type    = number
}

variable "custom_response_key" {
  type    = string
}

variable "custom_response_body" {
  type    = string
}

variable "enable_managed" {
  type    = bool
  default = true
}

variable "managed_rules" {
  type = list(object({
    enabled    = bool
    name       = string
    priority   = number
    vendor     = string
    rule_group = string
  }))
  default = []
}

variable "enable_custom" {
  type    = bool
  default = true
}

variable "custom_rules" {
  type = list(object({
    enabled       = bool
    name          = string
    priority      = number
    type          = string
    action        = string
    limit         = optional(number)
    aggregate_key = optional(string)
    evaluation_window_sec    = optional(number)
    enable_custom_response   = optional(bool, false)
    custom_response_code     = optional(number)
    custom_response_body_key = optional(string)
    statements    = list(object({
      field                 = string
      search_string         = string
      positional_constraint = string
      limit                 = optional(number)
      aggregate_key         = optional(string)
    }))
  }))
  default = []
}
variable "enable_logging" {
  type = bool
  default = false
}

variable "log_destination_arns" {
  type    = list(string)
  default = []
}