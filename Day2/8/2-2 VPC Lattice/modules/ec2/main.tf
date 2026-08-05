resource "aws_security_group" "client" {
  name        = "skills-lattice-client-sg"
  description = "skills-lattice-client-sg"
  vpc_id      = var.vpc_1_id 
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Custom TCP (8080)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-lattice-client-sg" 
  }
} 

resource "aws_security_group" "service" {
  name   = "skills-lattice-service-sg"
  vpc_id = var.vpc_2_id 

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-lattice-service-sg"
  }
}

resource "aws_security_group" "client_assoc" {
  name   = "skills-lattice-client-assoc-sg"
  vpc_id = var.vpc_1_id 

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "skills-lattice-client-assoc-sg"
  }
}

resource "aws_iam_role" "this" {
  name               = "skills-lattice-iam-role"
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
  name = "skills-lattice-instance-profile"
  role = aws_iam_role.this.name
}



resource "aws_instance" "service" {
  ami           = data.aws_ssm_parameter.latest_ami.value
  subnet_id     = var.private_subnet_2_id
  instance_type = "t3.micro"
  vpc_security_group_ids      = [aws_security_group.service.id]
  associate_public_ip_address = false 
  iam_instance_profile        = aws_iam_instance_profile.this.name  
  user_data = templatefile("${path.module}/../../src/ec2/skills-lattice-service-ec2/userdata.sh", {})
  tags = {
    Name = "skills-lattice-service-ec2"
  }
}

resource "aws_instance" "client" {
  ami           = data.aws_ssm_parameter.latest_ami.value
  subnet_id     = var.public_subnet_1_id
  instance_type = "t3.micro"
  
  vpc_security_group_ids      = [aws_security_group.client.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.this.name
  user_data = templatefile("${path.module}/../../src/ec2/skills-lattice-client-ec2/userdata.sh", {
    SERVICE_URL     = format("http://%s", var.lattice_service_dns)
    CLIENT_PORT     = "80"
    SERVICE_TIMEOUT = "3"
  })
  
  tags = {
    Name = "skills-lattice-client-ec2"
  }
}