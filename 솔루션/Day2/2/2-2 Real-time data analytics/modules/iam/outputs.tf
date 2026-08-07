output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2.name
}

output "ec2_role_name" {
  value = aws_iam_role.ec2.name
}

output "flink_role_arn" {
  value = aws_iam_role.flink.arn
}

output "flink_role_name" {
  value = aws_iam_role.flink.name
}
