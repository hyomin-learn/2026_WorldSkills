resource "aws_sns_topic" "sensor_alert" {
  name = "${var.project}-sensor-alert-notify"

  tags = {
    Name = "${var.project}-sensor-alert-notify"
  }
}
