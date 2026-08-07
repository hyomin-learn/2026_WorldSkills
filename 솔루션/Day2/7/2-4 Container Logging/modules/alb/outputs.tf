output "alb_sg_id" {
  description = "ALB security group (TargetGroupBinding networking 에서 사용)"
  value       = aws_security_group.alb.id
}

output "app_tg_arn" {
  value = aws_lb_target_group.app.arn
}

output "grafana_tg_arn" {
  value = aws_lb_target_group.grafana.arn
}

output "app_alb_dns" {
  value = aws_lb.app.dns_name
}

output "grafana_alb_dns" {
  value = aws_lb.grafana.dns_name
}
