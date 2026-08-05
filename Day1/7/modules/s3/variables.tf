variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "enable_objects" {
  type = bool
  default = false
}

variable "objects" {
  type = list(object({
    key          = string
    source       = string
    content_type = optional(string)
  }))
  default = []
}

variable "enable_object_kms" {
  type = bool
  default = false
}

variable "kms_arn" {
  type = string
}

variable "block_public_access" {
  type = bool
  default = false
}

variable "block_public_acls" {
  type = bool
  default = true
}

variable "block_public_policy" {
  type = bool
  default = true
}

variable "ignore_public_acls" {
  type = bool
  default = true
}

variable "restrict_public_buckets" {
  type = bool
  default = true
}

variable "enable_versioning" {
  type = bool
  default = false
}