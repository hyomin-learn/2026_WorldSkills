variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "source_table_stream_arn" {
  description = "DynamoDB Streams ARN of the reservation table"
  type        = string
}

variable "audit_table_name" {
  description = "Audit table name (passed to Lambda as env var)"
  type        = string
}

variable "audit_table_arn" {
  description = "Audit table ARN (for write permission)"
  type        = string
}
