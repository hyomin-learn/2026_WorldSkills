output "security_group_client_assoc_id" {
  value = aws_security_group.client_assoc.id
}

output "security_group_service_sg" {
  value = aws_security_group.service.id
}

output "skills_lattice_service_instance_id" {
  value = aws_instance.service.id
}