variable "project" {
  type = string
}

variable "security_group_id" {
  description = "wsc2026-event-sg id (sg-remediation 대상)"
  type        = string
}

variable "instance_id" {
  description = "wsc2026-event-ec2 instance id (stop-remediation 대상)"
  type        = string
}
