variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "kms_key_id" {
  type    = string
  default = null
}

variable "create_log_stream" {
  type    = bool
  default = false
}

variable "log_stream_names" {
  type    = list(string)
  default = []
}

variable "create_metric_filter" {
  type    = bool
  default = false
}

variable "metric_filters" {
  type    = any
  default = []
}