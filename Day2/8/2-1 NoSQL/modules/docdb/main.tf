resource "aws_docdb_subnet_group" "this" {
  name       = "${var.project}-docdb-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project}-docdb-subnet-group"
  }
}

resource "aws_docdb_cluster_parameter_group" "this" {
  name        = "${var.project}-docdb-pg"
  family      = "docdb5.0"
  description = "TLS enabled parameter group for ${var.project}"

  parameter {
    name  = "tls"
    value = "enabled"
  }
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier              = "skills-nosql-docdb-cluster"
  engine                          = "docdb"
  engine_version                  = "5.0.0"
  master_username                 = var.master_username
  master_password                 = var.master_password
  db_subnet_group_name            = aws_docdb_subnet_group.this.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name
  vpc_security_group_ids          = [var.docdb_security_group_id]
  storage_encrypted               = true
  kms_key_id                      = var.kms_key_arn
  backup_retention_period         = var.backup_retention_period
  skip_final_snapshot             = true
  apply_immediately               = true
}

resource "aws_docdb_cluster_instance" "this" {
  identifier         = "skills-nosql-docdb-instance-1"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class
  engine             = "docdb"
  apply_immediately  = true
}
