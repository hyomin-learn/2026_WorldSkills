# 10. Load Balancing : wskorea26-book-alb (Internet-facing, HTTP 80)
#   - /book + POST + X-Origin-Verify:wskorea26-cf -> book app (EKS, NodePort, target_type=instance)
#   - /book + GET  + X-Origin-Verify:wskorea26-cf -> wskorea26-book-lambda (target_type=lambda)
#   - 그 외(CloudFront 를 거치지 않은 요청) -> 403 Forbidden (default action)

resource "aws_lb" "book" {
  name               = "wskorea26-book-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Name = "wskorea26-book-alb" }
}

# --------------------------- Target Group : book app (EKS NodePort) ---------------------------
resource "aws_lb_target_group" "book_app" {
  name        = "wskorea26-book-app-tg"
  port        = var.node_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "wskorea26-book-app-tg" }
}

# --------------------------- Target Group : wskorea26-book-lambda ---------------------------
resource "aws_lb_target_group" "lambda" {
  name        = "wskorea26-book-lambda-tg"
  target_type = "lambda"

  tags = { Name = "wskorea26-book-lambda-tg" }
}

resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id         = var.lambda_function_arn
  depends_on        = [aws_lambda_permission.alb]
}

# --------------------------- Listener : HTTP 80 ---------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.book.arn
  port                = 80
  protocol            = "HTTP"

  # CloudFront 를 거치지 않은(=Custom Header 없는) 요청은 모두 403
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "403 Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "book_post" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.book_app.arn
  }

  # CloudFront Function 이 POST /book -> /v1/book 으로 재작성해서 전달한다 (Reference02 app 경로).
  condition {
    path_pattern {
      values = ["/v1/book"]
    }
  }

  condition {
    http_request_method {
      values = ["POST"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values            = ["wskorea26-cf"]
    }
  }
}

resource "aws_lb_listener_rule" "lambda_get" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }

  condition {
    path_pattern {
      values = ["/book"]
    }
  }

  condition {
    http_request_method {
      values = ["GET"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values            = ["wskorea26-cf"]
    }
  }
}
