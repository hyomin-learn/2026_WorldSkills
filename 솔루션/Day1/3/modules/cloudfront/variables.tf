variable "tags" {
  type = map(string)
}

variable "s3_bucket_id" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "s3_bucket_regional_domain_name" {
  type = string
}

variable "lambda_function_url" {
  type = string
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "waf_id" {
  type = string
  default = null
}

variable "origin_path" {
  type = string
}

variable "default_root_object" {
  type = string
}

variable "enable_cloudfront_function" {
  type    = bool
  default = false
}

variable "cloudfront_function_name" {
  type = string
}

variable "cloudfront_function_runtime" {
  type = string
}

variable "cloudfront_function_publish" {
  type    = bool
  default = false
}

variable "cloudfront_function_code_path" {
  type = string
}