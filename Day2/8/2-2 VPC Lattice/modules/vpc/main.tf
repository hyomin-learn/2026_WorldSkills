resource "aws_vpc" "vpc_1" {
  cidr_block           = "10.61.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "skills-lattice-client-vpc"
  }
}

# Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.61.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "skills-lattice-client-public-a"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.vpc_1.id
  cidr_block        = "10.61.2.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "skills-lattice-client-private-a"
  }
}

# Internet Gateway 1
resource "aws_internet_gateway" "igw_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    Name = "skills-lattice-client-igw"
  }
}

# Elastic IP for NAT 1
resource "aws_eip" "nat_1" {
  domain = "vpc"
  tags = {
    Name = "skills-lattice-client-eip"
  }
}

# NAT Gateway 1
resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_1.id
  tags = {
    Name = "skills-lattice-client-ngw"
  }
}

# Public Route Table 1
resource "aws_route_table" "public_1" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_1.id
  }
  tags = {
    Name = "skills-lattice-client-public-rtb"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_1.id 
}

# Private Route Table 1
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_1.id
  }
  tags = {
    Name = "skills-lattice-client-private-rtb"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}


#======client_vpc=====
resource "aws_vpc" "vpc_2" {
  cidr_block           = "10.62.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "skills-lattice-service-vpc"
  }
}

# Subnets
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.vpc_2.id
  cidr_block              = "10.62.0.0/24" 
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "skills-lattice-service-public-a"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.vpc_2.id
  cidr_block        = "10.62.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "skills-lattice-service-private-a"
  }
}

# Internet Gateway 2
resource "aws_internet_gateway" "igw_2" {
  vpc_id = aws_vpc.vpc_2.id
  tags = {
    Name = "skills-lattice-service-igw"
  }
}

# Elastic IP 
resource "aws_eip" "nat_2" {
  domain = "vpc"
  tags = {
    Name = "skills-lattice-service-eip"
  }
}

# NAT Gateway 2
resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_2.id
  tags = {
    Name = "skills-lattice-service-ngw"
  }
}

# Public Route Table 2
resource "aws_route_table" "public_2" {
  vpc_id = aws_vpc.vpc_2.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_2.id
  }
  tags = {
    Name = "skills-lattice-service-public-rtb"
  }
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_2.id 
}

# Private Route Table 2
resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.vpc_2.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_2.id
  }
  tags = {
    Name = "skills-lattice-service-private-rtb"
  }
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}