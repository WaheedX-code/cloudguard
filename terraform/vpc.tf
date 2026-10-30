# Deliberately minimal, and deliberately free: no NAT Gateway anywhere
# in this environment (NAT Gateway is not free-tier eligible and bills
# per hour plus data processed). Lambda reaches S3 through the free
# S3 gateway VPC endpoint below instead, which is both free and, not
# coincidentally, the actual correct fix for real egress control work,
# a workload that never needs general internet access shouldn't have a
# path to it in the first place.

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.environment_name}-vpc" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = "${var.environment_name}-private" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Free: no hourly charge, no data processing charge, unlike a NAT
# Gateway or an interface endpoint.
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = [aws_route_table.private.id]

  tags = { Name = "${var.environment_name}-s3-endpoint" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.environment_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# SEEDED FINDING for Chain B, Project 6 (Attack Path Analysis and
# Network and Encryption Hardening): egress is wide open to
# 0.0.0.0/0 on all ports, when this Lambda function only ever needs to
# reach the S3 gateway endpoint above. A tightened version scoped to
# exactly that need is this project's actual deliverable, not
# something to pre-solve here.
resource "aws_security_group" "lambda_process_upload" {
  name        = "${var.environment_name}-process-upload-sg"
  description = "Security group for the process_upload Lambda function"
  vpc_id      = aws_vpc.main.id

  egress {
    description     = "HTTPS to the S3 gateway endpoint prefix list only"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
  }
}
