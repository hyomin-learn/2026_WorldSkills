variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project" {
  type    = string
  default = "wsc2026"
}

variable "student_id" {
  type        = string
  description = "선수 비번호 (apply 시 직접 입력)"
}

variable "manage_topics" {
  type        = bool
  default     = true
  description = "true(기본)면 EC2에 SSM 명령으로 Kafka 토픽을 자동 생성(정확한 partition/RF 지정). destroy 후 재생성해도 매번 자동으로 만들어짐. false면 만들지 않음(수동 생성 필요)."
}

variable "vpc_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1d"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["192.168.0.0/24", "192.168.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["192.168.10.0/24", "192.168.11.0/24"]
}

variable "msk_kafka_version" {
  type    = string
  default = "3.6.0"
}

variable "msk_instance_type" {
  type    = string
  default = "kafka.t3.small"
}

variable "msk_broker_count" {
  type    = number
  default = 2
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.small"
}

variable "raw_topic_name" {
  type    = string
  default = "wsc2026-sensor-raw"
}

variable "raw_topic_partitions" {
  type    = number
  default = 3
}

variable "raw_topic_replication_factor" {
  type    = number
  default = 2
}

variable "alert_topic_name" {
  type    = string
  default = "wsc2026-sensor-alert"
}

variable "alert_topic_partitions" {
  type    = number
  default = 1
}

variable "alert_topic_replication_factor" {
  type    = number
  default = 2
}

variable "dynamodb_table_name" {
  type    = string
  default = "wsc2026-sensor-data"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.14"
}
