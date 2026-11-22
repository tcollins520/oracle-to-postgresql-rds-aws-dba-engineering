# Networking resources.
# Networking foundation for the Oracle RDS migration environment.
# Design: one VPC, two public subnets, two private subnets across two AZs,
# single NAT Gateway, and a pair of route tables. This design is intentionally simple to reduce development costs.
# Do not put database instances in the public subnets.

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  nat_keys = var.enable_nat_gateway ? (var.single_nat_gateway ? toset(["az_a"]) : toset(["az_a", "az_b"])) : toset([])

  private_nat_routes = var.enable_nat_gateway ? (
    var.single_nat_gateway ? { az_a = "az_a", az_b = "az_a" } : { az_a = "az_a", az_b = "az_b" }
  ) : {}
}

# Project-isolated VPC; DNS settings support private DNS and service discovery.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-vpc" })
}

# Internet Gateway provides internet connectivity for resources in public subnets.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-igw" })
}

# Public subnets receive a default route to the Internet Gateway.
resource "aws_subnet" "public" {
  for_each                = var.public_subnet_cidrs
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[each.key]
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-${each.key}"
    Tier = "public"
  })
}

# Private subnets have no direct route to the Internet Gateway.s
resource "aws_subnet" "private" {
  for_each                = var.private_subnet_cidrs
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[each.key]
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-${each.key}"
    Tier = "private"
  })
}

# Elastic IP is required by the NAT Gateway for outbound IPv4 connectivity.
resource "aws_eip" "nat" {
  for_each = local.nat_keys
  domain   = "vpc"
  tags     = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-nat-eip-${each.key}" })
}

# NAT Gateway
resource "aws_nat_gateway" "this" {
  for_each      = local.nat_keys
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  depends_on    = [aws_internet_gateway.this]
  tags          = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-nat-${each.key}" })
}

# Public route table: send non-local IPv4 traffic to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-public-rt" })
}

# Public internet route
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Public subnet associations
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route table: send outbound IPv4 traffic through the single NAT Gateway.
resource "aws_route_table" "private" {
  for_each = var.private_subnet_cidrs
  vpc_id   = aws_vpc.this.id
  tags     = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-private-${each.key}-rt" })
}

# Private outbound route
resource "aws_route" "private_nat" {
  for_each               = local.private_nat_routes
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

# Private subnet associations
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# S3 gateway endpoint
# Provides private subnet resources with access to Amazon S3 without routing traffic through a NAT Gateway or internet gateway.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.private : route_table.id]
  tags              = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-s3-gateway-endpoint" })
}
