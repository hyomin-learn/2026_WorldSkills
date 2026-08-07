output "alb_arn"       { value = aws_lb.grafana.arn }
output "alb_dns_name"  { value = aws_lb.grafana.dns_name }
output "alb_name"      { value = aws_lb.grafana.name }
output "target_group_arn" { value = aws_lb_target_group.grafana.arn }
output "node_port"     { value = var.node_port }
