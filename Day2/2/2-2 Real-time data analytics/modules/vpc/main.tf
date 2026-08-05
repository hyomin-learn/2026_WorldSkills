# =====================================================================
# 1. VPC  (analytics-vpc / 10.20.0.0/16, 멀티 AZ 고가용성 구성)
# =====================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "analytics-vpc" }
}

# --------------------------- Public Subnets (a, b) ---------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.0.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "analytics-pub-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "analytics-pub-b" }
}

# --------------------------- Private Subnets (a, b) ---------------------------
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.100.0/24"
  availability_zone = var.availability_zones[0]
  tags              = { Name = "analytics-priv-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.101.0/24"
  availability_zone = var.availability_zones[1]
  tags              = { Name = "analytics-priv-b" }
}

# --------------------------- Internet Gateway ---------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "analytics-igw" }
}

# --------------------------- NAT Gateway (analytics-ngw) ---------------------------
# 표 기준: priv-a / priv-b 모두 단일 NAT(analytics-ngw)를 통해 아웃바운드.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "analytics-ngw-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "analytics-ngw" }
  depends_on    = [aws_internet_gateway.main]
}

# --------------------------- Public Route Table (analytics-pub-rtb) ---------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "analytics-pub-rtb" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# --------------------------- Private Route Tables (priv-a / priv-b) ---------------------------
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "analytics-priv-a-rtb" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "analytics-priv-b-rtb" }
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}
