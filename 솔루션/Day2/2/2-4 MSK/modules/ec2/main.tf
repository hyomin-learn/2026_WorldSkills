locals {
  topic_wildcard_arn = replace(var.msk_cluster_arn, ":cluster/", ":topic/") // cluster-name/uuid
  topic_wildcard_arn_full = "${local.topic_wildcard_arn}/*"
  group_wildcard_arn = "${replace(var.msk_cluster_arn, ":cluster/", ":group/")}/*"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-msk-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_msk_access" {
  name = "${var.project}-msk-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "MskClusterConnect"
        Effect   = "Allow"
        Action   = ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster"]
        Resource = var.msk_cluster_arn
      },
      {
        Sid    = "MskTopicManage"
        Effect = "Allow"
        Action = [
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:AlterTopic",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = local.topic_wildcard_arn_full
      },
      {
        Sid      = "MskGroup"
        Effect   = "Allow"
        Action   = ["kafka-cluster:AlterGroup", "kafka-cluster:DescribeGroup"]
        Resource = local.group_wildcard_arn
      },
      {
        Sid      = "AppBinaryDownload"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.app_bucket_name}/${var.app_object_key}"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-msk-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "producer" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    bootstrap_brokers_plaintext = var.bootstrap_brokers_plaintext
    raw_topic_name        = var.raw_topic_name
    app_bucket_name       = var.app_bucket_name
    app_object_key        = var.app_object_key
    aws_region            = var.region
  })

  tags = {
    Name = "${var.project}-sensor-producer"
  }
}
