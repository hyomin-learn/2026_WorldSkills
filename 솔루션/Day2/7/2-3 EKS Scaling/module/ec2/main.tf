#==== security_group ======
resource "aws_security_group" "this" {
  name        = "skm-sg"
  description = "Allow all inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skm-sg"
  }
}

#====== IAM ======
resource "aws_iam_role" "this" {
  name = "skm-bastion-iam-role" 

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "this" {
  name = "skm-bastion-instance-profile-v2"
  role = aws_iam_role.this.name
}
#====== instance ======
resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.latest_ami.value
  subnet_id                   = var.subnet_id
  instance_type               = "t3.medium"
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.this.name

user_data = templatefile("${path.root}/src/ec2/bastion/userdata", {
    aws_region          = "ap-northeast-2"
    REGION_CODE         = "ap-northeast-2"
    cluster_name        = "skm-eks-cluster"
    ecr_repo_name       = "skm-ecr"
    sqs_queue_url       = var.sqs_queue_url 
    karpenter_role_name = "eksctl-KarpenterNodeRole-skm-eks-cluster"
    private_subnet_a_id = var.private_subnet_a_id 
    private_subnet_c_id = var.private_subnet_c_id 
  })

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "skm-bastion"
  }
}