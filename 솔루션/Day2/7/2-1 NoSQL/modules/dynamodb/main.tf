# =============== Reservation Table ===============
resource "aws_dynamodb_table" "reservation" {
  name         = var.reservation_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "train_id"
  range_key    = "seat_id"

  attribute {
    name = "train_id"
    type = "S"
  }
  attribute {
    name = "seat_id"
    type = "S"
  }
  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "reserved_at"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  global_secondary_index {
    name            = var.gsi_name
    hash_key        = "user_id"
    range_key       = "reserved_at"
    projection_type = "ALL"
  }

  # 데이터 손실 대비
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = var.reservation_table_name
  }
}

# =============== Audit Table ===============
resource "aws_dynamodb_table" "audit" {
  name         = var.audit_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = var.audit_table_name
  }
}
