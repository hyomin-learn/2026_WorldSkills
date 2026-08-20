resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.keypair_name
  public_key = tls_private_key.this.public_key_openssh
}

resource "local_file" "this" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${path.cwd}/${var.keypair_name}.pem"
  file_permission = "0400"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  subnet_id                   = var.public_subnet_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name

  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/bastion.sh", {
    region           = var.region
    cluster_name     = var.cluster_name
    cluster_version  = var.cluster_version
    ecr_url          = var.ecr_repository_url
    artifacts_bucket  = var.artifacts_bucket
    competitor_number = var.competitor_number
    alb_sg_id         = var.alb_sg_id
    app_tg_arn        = var.app_tg_arn
    grafana_tg_arn    = var.grafana_tg_arn
    admin_arn         = var.admin_principal_arn
    vpc_id           = var.vpc_id
    az_a             = var.availability_zones[0]
    az_c             = var.availability_zones[1]
    pub_subnet_a     = var.public_subnet_ids[0]
    pub_subnet_c     = var.public_subnet_ids[1]
    priv_subnet_a    = var.private_subnet_ids[0]
    priv_subnet_c    = var.private_subnet_ids[1]
    app_py           = file("${path.root}/modules/app/app.py")
    dockerfile       = file("${path.root}/modules/app/Dockerfile")
  })

  tags = {
    Name = var.instance_name
  }
}

resource "aws_eip" "bastion" {
  domain     = "vpc"
  instance   = aws_instance.bastion.id
  tags       = { Name = "${var.instance_name}-eip" }
  depends_on = [aws_instance.bastion]
}

resource "null_resource" "bootstrap" {
  count = var.auto_deploy ? 1 : 0

  triggers = {
    instance_id = aws_instance.bastion.id
  }

  connection {
    type        = "ssh"
    host        = aws_eip.bastion.public_ip
    user        = "ec2-user"
    private_key = tls_private_key.this.private_key_pem
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '>>> waiting for bastion bootstrap (cloud-init)...'",
      "sudo cloud-init status --wait || true",
      "test -f /home/ec2-user/o11y/01-autodeploy.sh || { echo '!!! bootstrap failed - see /var/log/bastion-bootstrap.log'; sudo tail -30 /var/log/bastion-bootstrap.log; exit 1; }",
      "bash /home/ec2-user/o11y/01-autodeploy.sh",
    ]
  }

  depends_on = [aws_eip.bastion]
}
