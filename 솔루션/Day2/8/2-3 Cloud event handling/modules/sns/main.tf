resource "aws_sns_topic" "alert" {
  name = "${var.project}-alert-topic"

  tags = {
    Name = "${var.project}-alert-topic"
  }
}
