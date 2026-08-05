resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "studentId"
  range_key    = "examDate"

  attribute {
    name = "studentId"
    type = "S"
  }

  attribute {
    name = "examDate"
    type = "S"
  }
}
