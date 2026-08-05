# ---------------------------Security Group (App EC2)---------------------------
resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "Allow SSH(22) and Flask app(8080) traffic"
  vpc_id      = aws_vpc.main.id

  # Inbound - SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound - Flask application (TCP 8080)
  ingress {
    description = "Flask app"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-app-sg"
  }
}
