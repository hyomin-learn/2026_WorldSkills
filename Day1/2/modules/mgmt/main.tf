# 자동화 작업용 bastion. wskorea26-vpc 의 public subnet 에 배치하여
#   - 인터넷(IGW) 을 통해 eksctl/kubectl/helm/docker 설치 및 이미지 빌드/푸시
#   - 같은 VPC 내부이므로 EKS Private API 엔드포인트에도 도달 가능
# 채점 전 별도로 종료(destroy)하여 "불필요한 EC2" 감점을 피할 것을 권장.
resource "aws_security_group" "bastion" {
  name        = "${var.project}-mgmt-bastion-sg"
  description = "Mgmt bastion (automation only)"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-mgmt-bastion-sg" }
}

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

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-minimal-kernel-default-x86_64"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  subnet_id                   = var.public_subnet_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name
  user_data                   = file("${path.module}/bastion.sh")

  root_block_device {
    volume_size           = 30
    volume_type            = "gp3"
    encrypted              = true
    delete_on_termination  = true
    tags                   = { Name = "${var.instance_name}-root-volume" }
  }

  tags = { Name = var.instance_name }
}

resource "aws_eip" "bastion" {
  domain   = "vpc"
  instance = aws_instance.bastion.id
  tags     = { Name = "${var.instance_name}-eip" }
}
