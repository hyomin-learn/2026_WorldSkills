# =====================================================================
# Security Groups
#   - ALB SG : 인터넷에서 HTTP 80 만 허용
#   - EC2 SG : ALB SG 로부터 app_port 만 허용 (직접 외부 접근 불가)
#              SSM 접속은 인바운드 불필요(아웃바운드로 동작)
# =====================================================================
resource "aws_security_group" "alb" {
  name        = "${var.project}-analytics-alb-sg"
  description = "ALB SG - allow HTTP 80 from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-analytics-alb-sg" }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project}-analytics-ec2-sg"
  description = "EC2 SG - allow app traffic only from ALB SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-analytics-ec2-sg" }
}
