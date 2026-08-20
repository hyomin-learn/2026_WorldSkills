data "aws_lb_target_group" "user" {
  tags = {
    "ingress.k8s.aws/resource" = "${var.namespace}/${var.ingress_name}-user-svc:80"
  }
}

data "aws_lb_target_group" "product" {
  tags = {
    "ingress.k8s.aws/resource" = "${var.namespace}/${var.ingress_name}-product-svc:80"
  }
}

data "aws_lb_target_group" "stress" {
  tags = {
    "ingress.k8s.aws/resource" = "${var.namespace}/${var.ingress_name}-stress-svc:80"
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-dashboard"

  dashboard_body = templatefile("${path.module}/dashboard.json.tpl", {
    alb_id       = var.alb_arn_suffix
    region       = var.region
    cluster_name = var.cluster_name
    namespace    = var.namespace
    rds_id       = var.rds_id
    tg_user      = data.aws_lb_target_group.user.arn_suffix
    tg_product   = data.aws_lb_target_group.product.arn_suffix
    tg_stress    = data.aws_lb_target_group.stress.arn_suffix
  })
}