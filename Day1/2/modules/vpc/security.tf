# --------------------------------------------------------------------------
# 2-13) 채점용 보안그룹 : wskorea26-vpc-environment-sg
#   Cloudshell VPC Environment(사전준비, priv-subnet-d)에 부여되어 EKS Private
#   API 엔드포인트에 접근할 수 있어야 한다. (Outbound 80/443 Anyopen 허용)
# --------------------------------------------------------------------------
resource "aws_security_group" "vpc_environment" {
  name        = "${var.project}-vpc-environment-sg"
  description = "Cloudshell VPC Environment - EKS Private endpoint access"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTP anyopen"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "HTTPS anyopen"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-vpc-environment-sg" }
}

# --------------------------------------------------------------------------
# 10) book ALB Security Group (Internet-facing, HTTP 80 Inbound Anyopen)
# --------------------------------------------------------------------------
resource "aws_security_group" "book_alb" {
  name        = "${var.project}-book-alb-sg"
  description = "wskorea26-book-alb - HTTP 80 inbound anyopen"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP anyopen"
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

  tags = { Name = "${var.project}-book-alb-sg" }
}

# --------------------------------------------------------------------------
# 12) Monitoring - Grafana ALB Security Group (Internet-facing, HTTP 80)
# --------------------------------------------------------------------------
resource "aws_security_group" "grafana_alb" {
  name        = "${var.project}-grafana-alb-sg"
  description = "wskorea26-grafana-alb - HTTP 80 inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP anyopen"
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

  tags = { Name = "${var.project}-grafana-alb-sg" }
}

# --------------------------------------------------------------------------
# EKS 노드가 두 ALB(NodePort 대상)로부터 트래픽을 받을 수 있도록 하는 SG.
# 이 SG는 두 ALB의 대상 EC2 인스턴스(관리형 노드그룹)에 추가로 부착한다.
# (nodegroup 은 eksctl 이 만들지만, 노드 인스턴스에 추가 SG 를 지정할 수 있다)
# --------------------------------------------------------------------------
resource "aws_security_group" "node_extra" {
  name        = "${var.project}-node-extra-sg"
  description = "Allow NodePort traffic from ALBs"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NodePort from book ALB"
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = [aws_security_group.book_alb.id, aws_security_group.grafana_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-node-extra-sg" }
}
