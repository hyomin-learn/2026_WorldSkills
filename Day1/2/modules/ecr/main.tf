# 6. Elastic Container Registry : wskorea26-book-repo
#   - Private, scan on push, KMS 암호화, stable 태그 사용
resource "aws_ecr_repository" "book" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = { Name = var.repository_name }
}
