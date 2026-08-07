variable "project" {
  type = string
}

variable "security_group_id" {
  description = "wsc2026-event-sg id (sg-change-rule 필터용)"
  type        = string
}

variable "instance_id" {
  description = "wsc2026-event-ec2 instance id (stop/terminate 필터용)"
  type        = string
}

variable "function_arns" {
  description = "Lambda ARNs map keyed by sg/stop/terminate/tag"
  type        = map(string)
}

variable "function_names" {
  description = "Lambda names map keyed by sg/stop/terminate/tag"
  type        = map(string)
}

variable "required_tags_rule_name" {
  description = "wsc2026-required-tags-rule (AWS Config Rule) 이름 - tag-alert 트리거 필터용"
  type        = string
}
