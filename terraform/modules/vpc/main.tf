# terraform/modules/vpc/main.tf

# ── VPC ─────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Required: gives EC2s internal DNS names
  enable_dns_support   = true  # Required: enables Route 53 Resolver

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ── PUBLIC SUBNETS ───────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # Instances here get public IPs automatically

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

# ── PRIVATE APP SUBNETS ──────────────────────────────────────────
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false  # Private — no public IPs

  tags = {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  }
}

# ── DB SUBNETS ───────────────────────────────────────────────────
resource "aws_subnet" "database" {
  count = length(var.db_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-db-${var.availability_zones[count.index]}"
    Tier = "database"
  }
}

# ── INTERNET GATEWAY ─────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id  # Attach immediately on creation

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ── NAT GATEWAY (REMOVED FOR FREE TIER) ─────────────────────────
# NAT Gateways cost ~$32/month + data processing fees — NOT free tier.
# Elastic IPs for NAT also cost ~$3.65/month each.
# For production: uncomment the aws_eip and aws_nat_gateway resources
# and update private route tables to route 0.0.0.0/0 through NAT.
# Web servers are deployed in PUBLIC subnets, so NAT is not needed
# for the current architecture.

# ── PUBLIC ROUTE TABLE ───────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Default route: everything not in VPC goes to internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate all public subnets with the public route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── PRIVATE ROUTE TABLES ────────────────────────────────────────
# Private subnets have NO internet access (no NAT GW in free tier).
# They can still communicate within the VPC via local routes (automatic).
# For production: add a route to NAT GW for outbound internet access.
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  # No default route — private subnets are isolated from internet
  # VPC local route (10.0.0.0/16 → local) is added automatically

  tags = {
    Name = "${var.project_name}-private-rt-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# DB subnets also use private route tables (isolated, no internet)
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}