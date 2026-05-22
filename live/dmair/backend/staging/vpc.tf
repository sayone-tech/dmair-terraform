# Dedicated VPC for dmair-backend staging. Independent of every other VPC
# in the account — never shared with the existing Strapi/frontend stacks.
#
# Layout:
#   - 2 public subnets  (10.0.0.0/24, 10.0.1.0/24)  — EC2 + IGW.
#   - 2 private subnets (10.0.2.0/24, 10.0.3.0/24)  — RDS only.
#     RDS needs a DB subnet group across >=2 AZs even for a Single-AZ
#     instance; private subnets satisfy that without exposing the DB.
#
# No NAT gateway. The private subnets don't need outbound internet —
# RDS doesn't initiate connections; EC2 reaches it via VPC-internal
# routing (private subnets share the VPC's main local route).

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "dmair-staging-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "dmair-staging-igw"
  }
}

# --- Public subnets (EC2) ---------------------------------------------

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "dmair-staging-public-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "dmair-staging-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private subnets (RDS) --------------------------------------------

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "dmair-staging-private-${count.index}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Deliberately no `route` block — VPC's implicit local route handles
  # in-VPC traffic. No 0.0.0.0/0 route means no outbound internet from
  # private subnets, which is desired (RDS doesn't initiate connections).

  tags = {
    Name = "dmair-staging-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
