resource "aws_security_group" "ec2" {
  name        = "${var.project}-msk-ec2-sg"
  description = "Sensor producer EC2 security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-msk-ec2-sg"
  }
}

resource "aws_security_group" "lambda" {
  name        = "${var.project}-msk-lambda-sg"
  description = "MSK consumer Lambda security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-msk-lambda-sg"
  }
}

resource "aws_security_group" "msk" {
  name        = "${var.project}-msk-cluster-sg"
  description = "MSK broker security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-msk-cluster-sg"
  }
}

resource "aws_security_group_rule" "msk_from_ec2" {
  type                     = "ingress"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  security_group_id        = aws_security_group.msk.id
  source_security_group_id = aws_security_group.ec2.id
  description               = "IAM auth from producer EC2"
}

resource "aws_security_group_rule" "msk_plaintext_from_ec2" {
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  security_group_id        = aws_security_group.msk.id
  source_security_group_id = aws_security_group.ec2.id
  description               = "Plaintext access from producer EC2 (app has no IAM/SASL support)"
}

resource "aws_security_group_rule" "msk_from_lambda" {
  type                     = "ingress"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  security_group_id        = aws_security_group.msk.id
  source_security_group_id = aws_security_group.lambda.id
  description               = "IAM auth from consumer Lambda"
}

# AWS Lambda's MSK event source mapping (poller) "belongs to" the MSK cluster's
# own security group when it talks to the brokers - not the Lambda function's
# configured VPC security group. It therefore needs the MSK SG to allow itself.
resource "aws_security_group_rule" "msk_self_9098" {
  type                     = "ingress"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  security_group_id        = aws_security_group.msk.id
  source_security_group_id = aws_security_group.msk.id
  description               = "Self-reference required by MSK Lambda event source mapping"
}
