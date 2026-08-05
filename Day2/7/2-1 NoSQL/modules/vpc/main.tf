# ---------------------------VPC & Subnets---------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project}-vpc" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project}-sn-pub-${count.index == 0 ? "a" : "b"}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.project}-sn-priv-${count.index == 0 ? "a" : "b"}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

# --------------------------- NAT Gateway ---------------------------

resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags   = { Name = "${var.project}-ngw-eip-a" }
}

resource "aws_eip" "nat_c" {
  domain = "vpc"
  tags   = { Name = "${var.project}-ngw-eip-b" }
}

resource "aws_nat_gateway" "main_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.project}-ngw-a" }
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main_c" {
  allocation_id = aws_eip.nat_c.id
  subnet_id     = aws_subnet.public[1].id
  tags          = { Name = "${var.project}-ngw-b" }
  depends_on    = [aws_internet_gateway.main]
}

# --------------------------- Route Tables ---------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project}-pub-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_a.id
  }
  tags = { Name = "${var.project}-priv-rt-a" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private[0].id
  route_table_id = aws_route_table.private_a.id
}


resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_c.id
  }
  tags = { Name = "${var.project}-priv-rt-b" }
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private[1].id
  route_table_id = aws_route_table.private_c.id
}
