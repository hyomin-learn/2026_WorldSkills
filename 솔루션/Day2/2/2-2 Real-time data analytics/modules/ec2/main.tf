# =====================================================================
# 2. EC2  (wsc2026-analytics-ec2, t3.small, Private Subnet, SSM 접근)
# =====================================================================
# Amazon Linux 2023 최신 AMI (SSM Agent 기본 포함)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.ec2_sg_id]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = false

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_py_b64  = base64encode(file("${path.module}/app/app.py"))
    reqs_b64    = base64encode(file("${path.module}/app/requirements.txt"))
    stream_name = var.stream_name
    aws_region  = var.aws_region
    app_port    = var.app_port
  })

  tags = { Name = "${var.project}-analytics-ec2" }
}

# =====================================================================
# 3. Application Load Balancer
#    ALB : wsc2026-analytics-alb  (HTTP 80)
#    TG  : wsc2026-analytics-tg
# =====================================================================
resource "aws_lb" "alb" {
  name               = "${var.project}-analytics-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Name = "${var.project}-analytics-alb" }
}

resource "aws_lb_target_group" "tg" {
  name        = "${var.project}-analytics-tg"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = { Name = "${var.project}-analytics-tg" }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
