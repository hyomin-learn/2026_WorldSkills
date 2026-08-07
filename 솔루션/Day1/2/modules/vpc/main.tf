# =========================================================================
# 3. Network Configuration (Reference01)
#   VPC: wskorea26-vpc (172.16.0.0/16)
#   Public : wskorea26-pub-subnet-c / -d  -> wskorea26-public-rtb  -> book-igw
#   Private: wskorea26-priv-subnet-c / -d -> wskorea26-private-rtb-c/d -> book-ngw-c/d
# =========================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project}-vpc" }
}

# --------------------------- Internet Gateway ---------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "book-igw" }
}

# --------------------------- Public Subnets ---------------------------
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block               = each.value.cidr
  availability_zone        = each.value.az
  map_public_ip_on_launch  = true

  tags = { Name = "${var.project}-pub-subnet-${each.key}" }
}

# --------------------------- Private Subnets ---------------------------
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block               = each.value.cidr
  availability_zone        = each.value.az
  map_public_ip_on_launch  = false

  tags = {
    Name                             = "${var.project}-priv-subnet-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# --------------------------- NAT Gateways (book-ngw-c / book-ngw-d) ---------------------------
resource "aws_eip" "nat" {
  for_each = var.private_subnets
  domain   = "vpc"
  tags     = { Name = "book-ngw-${each.key}-eip" }
}

resource "aws_nat_gateway" "main" {
  for_each      = var.private_subnets
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags       = { Name = "book-ngw-${each.key}" }
  depends_on = [aws_internet_gateway.main]
}

# --------------------------- Public Route Table (공용, 2개 서브넷 공유) ---------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-public-rtb" }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each       = var.public_subnets
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# --------------------------- Private Route Tables (AZ별 분리) ---------------------------
resource "aws_route_table" "private" {
  for_each = var.private_subnets
  vpc_id   = aws_vpc.main.id
  tags     = { Name = "${var.project}-private-rtb-${each.key}" }
}

resource "aws_route" "private_nat" {
  for_each               = var.private_subnets
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id          = aws_nat_gateway.main[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each       = var.private_subnets
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
