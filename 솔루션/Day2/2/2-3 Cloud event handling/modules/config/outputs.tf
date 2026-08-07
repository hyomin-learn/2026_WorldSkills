output "sg_ssh_rule_name" {
  value = aws_config_config_rule.sg_ssh.name
}

output "required_tags_rule_name" {
  value = aws_config_config_rule.required_tags.name
}

output "recorder_name" {
  value = aws_config_configuration_recorder.recorder.name
}

output "config_bucket_name" {
  value = aws_s3_bucket.config.id
}
