output "bucket_name" {
  value = aws_s3_bucket.artifacts.id
}

# Bastion user_data 가 이 객체들에 depends_on 걸어 업로드 완료를 보장
output "object_keys" {
  value = [for o in aws_s3_object.kubernetes : o.key]
}
