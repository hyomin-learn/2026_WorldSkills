data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

output "repository_url" {
  value = aws_ecr_repository.book.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.book.arn
}

output "repository_name" {
  value = aws_ecr_repository.book.name
}
