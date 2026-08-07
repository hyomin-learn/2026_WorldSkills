variable "project" {
  type = string
}

variable "reservation_table_name" {
  description = "Reservation table name"
  type        = string
}

variable "audit_table_name" {
  description = "Audit table name"
  type        = string
}

variable "gsi_name" {
  description = "GSI name for user reservations"
  type        = string
}
