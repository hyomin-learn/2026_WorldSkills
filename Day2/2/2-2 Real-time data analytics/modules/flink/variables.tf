variable "project" {
  type = string
}

variable "service_execution_role" {
  description = "IAM role ARN for the Flink Studio Notebook (wsc2026-analytics-flink-role)"
  type        = string
}

variable "glue_database_name" {
  description = "Glue Data Catalog DB for the Studio Notebook (must match iam module)"
  type        = string
  default     = "wsc2026_analytics_db"
}

variable "runtime_environment" {
  description = <<-EOT
    Studio Notebook runtime. AWS currently supports ZEPPELIN-FLINK-3_0 (Flink 1.15)
    for Studio. The assignment requests "Apache Flink 1.19"; switch this value once
    a ZEPPELIN-FLINK runtime backed by 1.19 becomes available in the grading account.
  EOT
  type        = string
  default     = "ZEPPELIN-FLINK-3_0"
}

variable "role_propagation_delay" {
  description = "Wait time for the IAM role trust policy to propagate before creating the app (awscc has no assume-role retry)"
  type        = string
  default     = "60s"
}
