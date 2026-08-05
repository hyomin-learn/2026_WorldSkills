output "bucket_id" {
  value = aws_s3_bucket.app.id
}

output "bucket_arn" {
  value = aws_s3_bucket.app.arn
}

output "docdb_client_object_key" {
  value = aws_s3_object.docdb_client_py.key
}

output "retail_dataset_object_key" {
  value = aws_s3_object.retail_dataset_json.key
}
