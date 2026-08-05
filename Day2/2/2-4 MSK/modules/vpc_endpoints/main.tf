resource "aws_security_group" "endpoints" {
  name        = "${var.project}-vpc-endpoints-sg"
  description = "Allow HTTPS from the MSK cluster SG (the event source mapping poller uses the MSK cluster security group)"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.msk_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-vpc-endpoints-sg"
  }
}

# AWS Lambda's MSK/Kafka event source poller runs from ENIs inside your VPC and
# needs to reach the STS and Lambda service APIs itself (independent of NAT
# reachability quirks); without these, event source mappings can get stuck
# reporting a generic "Connection error".
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type    = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-sts-endpoint"
  }
}

resource "aws_vpc_endpoint" "lambda" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.lambda"
  vpc_endpoint_type    = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-lambda-endpoint"
  }
}
