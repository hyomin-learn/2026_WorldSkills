output "bastion_public_ip" {
  value = aws_eip.bastion.public_ip
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "bastion_private_key_pem" {
  value     = tls_private_key.this.private_key_pem
  sensitive = true
}
