output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_a_id" {
  value = aws_subnet.public_1.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_2.id
}

output "private_subnet_a_id" {
  value = aws_subnet.private_1.id
}

output "private_subnet_b_id" {
  value = aws_subnet.private_2.id
}

output "nat_gateway_a_id" {
  value = aws_nat_gateway.this_a.id
}

output "nat_gateway_c_id" {
  value = aws_nat_gateway.this_c.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.this.id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_a_id" {
  value = aws_route_table.private_1.id
}

output "private_route_table_c_id" {
  value = aws_route_table.private_2.id
}