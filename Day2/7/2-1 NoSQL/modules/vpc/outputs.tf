output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public Subnet ID List"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private Subnet ID List"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (A and B)"
  value       = [aws_nat_gateway.main_a.id, aws_nat_gateway.main_c.id]
}

output "nat_gateway_public_ips" {
  description = "NAT Gateway Public IPs"
  value       = [aws_eip.nat_a.public_ip, aws_eip.nat_c.public_ip]
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private Route Table IDs"
  value       = [aws_route_table.private_a.id, aws_route_table.private_c.id]
}

output "app_sg_id" {
  description = "App EC2 Security Group ID"
  value       = aws_security_group.app.id
}
