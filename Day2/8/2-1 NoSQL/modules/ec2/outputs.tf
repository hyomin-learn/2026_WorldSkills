output "public_ip" {
  value = aws_instance.client.public_ip
}

output "instance_id" {
  value = aws_instance.client.id
}
