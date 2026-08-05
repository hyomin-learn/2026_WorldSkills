variable "project" {
  type = string
}

variable "stream_arn" {
  description = "Kinesis order stream ARN (least-privilege scoping)"
  type        = string
}

variable "glue_database_name" {
  description = "Glue Data Catalog DB used by the Flink Studio Notebook (must match flink module)"
  type        = string
  default     = "wsc2026_analytics_db"
}
