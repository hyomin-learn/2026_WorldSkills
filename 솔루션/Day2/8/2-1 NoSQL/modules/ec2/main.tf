data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project}-client-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "ec2_permissions" {
  statement {
    sid       = "GetDocdbSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.secret_arn]
  }

  statement {
    sid       = "DecryptKms"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  statement {
    sid       = "GetAppFiles"
    actions   = ["s3:GetObject"]
    resources = ["${var.app_bucket_arn}/*"]
  }

  statement {
    sid       = "ListAppBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.app_bucket_arn]
  }
}

resource "aws_iam_role_policy" "ec2" {
  name   = "${var.project}-client-ec2-policy"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_permissions.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-client-ec2-profile"
  role = aws_iam_role.ec2.name
}

locals {
  key_name = var.key_name != "" ? var.key_name : null
}

resource "aws_instance" "client" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.client_security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  key_name                    = local.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    app_bucket                = var.app_bucket_name
    docdb_client_object_key   = var.docdb_client_object_key
    retail_dataset_object_key = var.retail_dataset_object_key
  })

  tags = {
    Name = "skills-nosql-client-ec2"
  }
}
