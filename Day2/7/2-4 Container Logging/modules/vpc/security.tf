# ---------------------------Security Group (Bastion)---------------------------
# The app (8080) and Grafana (3000) are exposed through ALBs whose security
# groups are managed by the AWS Load Balancer Controller, so the bastion SG
# only needs SSH inbound.
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project}-bastion-sg"
  description = "Allow SSH to the bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-bastion-sg"
  }
}
