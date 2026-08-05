output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  value = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  value = { for k, v in aws_subnet.private : k => v.id }
}

output "public_subnet_ids_list" {
  value = [for k, v in aws_subnet.public : v.id]
}

output "private_subnet_ids_list" {
  value = [for k, v in aws_subnet.private : v.id]
}

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}

output "vpc_environment_sg_id" {
  value = aws_security_group.vpc_environment.id
}

output "book_alb_sg_id" {
  value = aws_security_group.book_alb.id
}

output "grafana_alb_sg_id" {
  value = aws_security_group.grafana_alb.id
}

output "node_extra_sg_id" {
  value = aws_security_group.node_extra.id
}
