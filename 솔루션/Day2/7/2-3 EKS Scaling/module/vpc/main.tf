resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "skm-vpc"
  }
}

#==== Subnets ====#
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true  
  tags = {
    Name = "skm-public-subnet-a"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = {
    Name = "skm-public-subnet-c"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "skm-private-subnet-a"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "skm-private-subnet-c"
  }
}

#==== Internet Gateway ====#
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "skm-igw"
  }
}

#==== Elastic IPs for NAT Gateways ====#
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags = {
    Name = "skm-eip-a"
  }
}

resource "aws_eip" "nat_c" {
  domain = "vpc"
  tags = {
    Name = "skm-eip-c"
  }
}

#==== NAT Gateways ====#
resource "aws_nat_gateway" "this_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "skm-ngw-a"
  }
}

resource "aws_nat_gateway" "this_c" {
  allocation_id = aws_eip.nat_c.id
  subnet_id     = aws_subnet.public_2.id

  tags = {
    Name = "skm-ngw-c"
  }
}

#==== Public Route Table ====#
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "skm-public-rtb"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

#==== Private Route Tables ====#
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this_a.id
  }
  tags = {
    Name = "skm-private-rtb-a"
  }
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this_c.id
  }
  tags = {
    Name = "skm-private-rtb-c"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}