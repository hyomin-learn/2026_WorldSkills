output "app_instance_id" {
  description = "App EC2 Instance ID"
  value       = aws_instance.app.id
}

output "bastion_public_ip" {
  description = "App EC2 Elastic IP (stable public IP)"
  value       = aws_eip.app.public_ip
}

output "app_private_ip" {
  description = "App EC2 Private IP"
  value       = aws_instance.app.private_ip
}
