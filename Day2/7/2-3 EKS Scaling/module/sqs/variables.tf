variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "name" {
  type    = string
  default = "skm-order-queue"
}

variable "fifo_queue" {
  type    = bool 
  default = false
}

variable "delay_seconds" {
  type    = number
  default = 0
}

variable "max_message_size" {
  type    = number
  default = 262144
}

variable "message_retention_seconds" {
  type    = number
  default = 345600
}

variable "receive_wait_time_seconds" {
  type    = number
  default = 20
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 30
}

variable "content_based_deduplication" {
  type    = bool 
  default = false
}

variable "fifo_throughput_limit" {
  type    = string
  default = "perQueue"
}

variable "deduplication_scope" {
  type    = string
  default = "perQueue"
}

variable "enable_kms" {
  type    = bool 
  default = false
}

variable "kms_key_id" {
  type    = string
  default = null
}

variable "kms_data_key_reuse_period_seconds" {
  type    = number
  default = 300
}

variable "sqs_managed_sse_enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
  default = {
    Name = "skm-order-queue"
  }
}