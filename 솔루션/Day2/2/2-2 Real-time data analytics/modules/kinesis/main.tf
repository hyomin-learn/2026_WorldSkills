# =====================================================================
# 4. Kinesis Data Stream  (wsc2026-order-stream, On-demand)
# =====================================================================
resource "aws_kinesis_stream" "order" {
  name = "${var.project}-order-stream"

  # On-demand capacity mode (shard_count 는 지정하지 않는다)
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = { Name = "${var.project}-order-stream" }
}
