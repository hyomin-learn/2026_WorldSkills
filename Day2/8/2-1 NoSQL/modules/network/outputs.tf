output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "client_security_group_id" {
  value = aws_security_group.client_ec2.id
}

output "docdb_security_group_id" {
  value = aws_security_group.docdb.id
}
