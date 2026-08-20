resource "aws_ecr_repository" "user" {
  name                 = "apdev-user-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {Name = "apdev-user-ecr"}
}

resource "aws_ecr_repository" "product" {
  name                 = "apdev-product-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {Name = "apdev-product-ecr"}
}

resource "aws_ecr_repository" "stress" {
  name                 = "apdev-stress-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {Name = "apdev-stress-ecr"}
}