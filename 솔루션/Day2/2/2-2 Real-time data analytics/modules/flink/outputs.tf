output "application_name" {
  value = awscc_kinesisanalyticsv2_application.studio.application_name
}

output "application_id" {
  value = awscc_kinesisanalyticsv2_application.studio.id
}

output "glue_database_name" {
  value = aws_glue_catalog_database.studio.name
}
