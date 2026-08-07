output "ssh_command" {
  value = "ssh -i ${var.key_pair_name}.pem ec2-user@${module.mgmt.bastion_public_ip}"
}

output "grafana_alb_dns_name" {
  value = module.monitoring_alb.alb_dns_name
}

output "grafana_admin_user" {
  value = "skills-${var.exam_number}-admin"
}
