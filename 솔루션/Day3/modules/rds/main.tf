resource "aws_db_subnet_group" "this" {
  name = "apdev-db-subnet-group"

  subnet_ids = [
    var.private_protect_subnet_a_id,
    var.private_protect_subnet_c_id
  ]

  tags = {
    Name = "apdev-db-subnet-group"
  }
}

resource "aws_security_group" "this" {
  name        = "apdev-rds-sg"
  description = "RDS Security Group"
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
    Name = "apdev-rds-sg"
  }
}

resource "aws_db_instance" "this" {
  identifier = "apdev-rds-instance"

  engine         = "mysql"
  engine_version = "8.0"

  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  username = var.db_username
  password = var.db_password

  db_name = "apdev"
  port    = 3306

  multi_az            = true
  publicly_accessible = false

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  parameter_group_name = aws_db_parameter_group.this.name
  option_group_name    = aws_db_option_group.this.name

  enabled_cloudwatch_logs_exports = [
    "error",
    "general",
    "iam-db-auth-error",
    "slowquery"
  ]

  skip_final_snapshot = true

  tags = {
    Name = "apdev-rds-instance"
  }
}

resource "null_resource" "init_db" {
  depends_on = [aws_db_instance.this]

  triggers = {
    db_endpoint = aws_db_instance.this.address
  }
}

resource "aws_db_parameter_group" "this" {
  name        = "apdev-parameter-group"
  family      = "mysql8.0"
  description = "APDEV MySQL 8.0 parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "200"
  }

  tags = {
    Name = "apdev-parameter-group"
  }
  
  parameter {
    name  = "general_log"
    value = "1"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "1"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }
}

resource "aws_db_option_group" "this" {
  name                     = "apdev-option-group"
  engine_name              = "mysql"
  major_engine_version     = "8.0"
  option_group_description = "APDEV MySQL 8.0 option group"

  tags = {
    Name = "apdev-option-group"
  }
}