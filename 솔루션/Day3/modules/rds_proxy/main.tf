resource "aws_security_group" "this" {
  name        = "apdev-rds-proxy-sg"
  description = "RDS Proxy Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "apdev-rds-proxy-sg"
  }
}

resource "aws_iam_role" "this" {
  name = "apdev-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "rds.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "apdev-rds-proxy-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = var.proxy_secret_arn
      }
    ]
  })
}

resource "aws_db_proxy" "this" {

  depends_on = [
    aws_iam_role_policy.this
  ]

  name                   = "apdev-rds-proxy"
  engine_family          = "MYSQL"

  role_arn               = aws_iam_role.this.arn

  vpc_subnet_ids = [
    var.private_subnet_a_id,
    var.private_subnet_b_id
  ]

  vpc_security_group_ids = [
    aws_security_group.this.id
  ]

  auth {

    auth_scheme = "SECRETS"

    iam_auth = "DISABLED"

    secret_arn = var.proxy_secret_arn
  }

  require_tls = false
}

resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name
}

resource "aws_db_proxy_target" "this" {

  db_proxy_name = aws_db_proxy.this.name

  target_group_name = aws_db_proxy_default_target_group.this.name

  db_instance_identifier = var.db_instance_identifier
}