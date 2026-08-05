# 12. Monitoring : wskorea26-grafana-alb (Internet-facing, HTTP 80 -> Grafana)
resource "aws_lb" "grafana" {
  name               = "wskorea26-grafana-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Name = "wskorea26-grafana-alb" }
}

resource "aws_lb_target_group" "grafana" {
  name        = "wskorea26-grafana-tg"
  port        = var.node_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "wskorea26-grafana-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.grafana.arn
  port                = 80
  protocol            = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}
