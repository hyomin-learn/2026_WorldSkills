variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project" {
  type    = string
  default = "wsc2026"
}

variable "student_number" {
  type        = string
  description = "선수 비번호 (S3 버킷 이름 접미사로 사용, apply 시 직접 입력)"
}

variable "bucket_name_prefix" {
  type    = string
  default = "wsc2026-student-score-bucket"
}

variable "dynamodb_table_name" {
  type    = string
  default = "wsc2026-student-score"
}

variable "score_function_name" {
  type    = string
  default = "wsc2026-student-score-function"
}

variable "trigger_function_name" {
  type    = string
  default = "wsc2026-student-score-trigger-function"
}

variable "state_machine_name" {
  type    = string
  default = "wsc2026-student-score-workflow"
}

variable "lambda_role_name" {
  type    = string
  default = "wsc2026-lambda-student-role"
}

variable "stepfunction_role_name" {
  type    = string
  default = "wsc2026-stepfunction-student-role"
}
