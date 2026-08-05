variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }
variable "node_port" {
  type    = number
  default = 30080
}
variable "lambda_function_name" { type = string }
variable "lambda_function_arn" { type = string }
