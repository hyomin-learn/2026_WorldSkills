output "vpc_1_id" {
  value = aws_vpc.vpc_1.id
}

output "vpc_2_id" {
  value = aws_vpc.vpc_2.id
}

# --- Internet Gateways ---
output "internet_gateway_1_id" {
  value = aws_internet_gateway.igw_1.id
}

output "internet_gateway_2_id" {
  value = aws_internet_gateway.igw_2.id
}

# --- NAT Gateways ---
output "nat_gateway_1_id" { 
  value = aws_nat_gateway.nat_gw_1.id
}

output "nat_gateway_2_id" { 
  value = aws_nat_gateway.nat_gw_2.id
}

# --- Subnets ---
output "public_subnet_1_id" {
  value = aws_subnet.public_1.id
}

output "private_subnet_1_id" {
  value = aws_subnet.private_1.id
}

output "public_subnet_2_id" {
  value = aws_subnet.public_2.id
}

output "private_subnet_2_id" {
  value = aws_subnet.private_2.id
}

# --- Route Tables ---
output "public_route_table_1_id" {
  value = aws_route_table.public_1.id
}

output "private_route_table_1_id" {
  value = aws_route_table.private_1.id
}

output "public_route_table_2_id" {
  value = aws_route_table.public_2.id
}

output "private_route_table_2_id" {
  value = aws_route_table.private_2.id
}