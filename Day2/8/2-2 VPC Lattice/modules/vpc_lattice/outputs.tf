output "target_group_ids" {
  value = aws_vpclattice_target_group.this.id
}

output "security_group_client_assoc_id" {
  value = var.client_assoc_sg_id
}

output "skills_lattice_service_instance_id" {
  value = var.lattice_service_instance_id
}

output "service_dns_name" {
  value = aws_vpclattice_service.this.dns_entry[0].domain_name
}

output "vpc_lattice_service_id" {
  value = aws_vpclattice_service.this.id
}

output "vpc_lattice_service_network_id" {
  value = aws_vpclattice_service_network.this.id
}

output "vpc_lattice_target_group_id" {
  value = aws_vpclattice_target_group.this.id
}