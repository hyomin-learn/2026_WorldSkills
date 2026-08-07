output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion Elastic IP (fixed across reboots)"
  value       = aws_eip.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}
