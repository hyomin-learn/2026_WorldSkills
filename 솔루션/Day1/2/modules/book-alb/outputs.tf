output "alb_arn" {
  value = aws_lb.book.arn
}

output "alb_dns_name" {
  value = aws_lb.book.dns_name
}

output "alb_name" {
  value = aws_lb.book.name
}

output "book_target_group_arn" {
  value = aws_lb_target_group.book_app.arn
}

output "node_port" {
  value = var.node_port
}
