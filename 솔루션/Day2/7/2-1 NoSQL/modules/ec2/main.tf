# --------------------------- Key Pair ---------------------------
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.keypair_name
  public_key = tls_private_key.this.public_key_openssh

  tags = { Name = var.keypair_name }
}

resource "local_file" "this" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${path.cwd}/${var.keypair_name}.pem"
  file_permission = "0400"
}

# --------------------------- Deploy ---------------------------
locals {
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_py_b64       = base64encode(file("${path.module}/app/app.py"))
    requirements_b64 = base64encode(file("${path.module}/app/requirements.txt"))
    aws_region       = var.aws_region
    table_name       = var.table_name
    gsi_name         = var.gsi_name
  })
}

# --------------------------- EC2 ---------------------------
resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.latest_ami.value
  subnet_id                   = var.public_subnet_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  vpc_security_group_ids      = [var.app_sg_id]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name
  user_data                   = local.user_data

  tags = {
    Name = var.instance_name
  }
}

# --------------------------- Elastic IP ---------------------------
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id

  tags = {
    Name = "${var.instance_name}-eip"
  }

  depends_on = [aws_instance.app]
}
