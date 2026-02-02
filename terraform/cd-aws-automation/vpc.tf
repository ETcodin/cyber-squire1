# --- VPC INFRASTRUCTURE (CD-Standard Naming) ---
# Custom VPC for CD-AWS-AUTOMATION with public/private subnet isolation

# --- VPC ---
resource "aws_vpc" "cd_net_vpc_01" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "cd-net-vpc-01"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "Custom VPC for production-grade infrastructure"
  }
}

# --- INTERNET GATEWAY ---
resource "aws_internet_gateway" "cd_net_igw_01" {
  vpc_id = aws_vpc.cd_net_vpc_01.id

  tags = {
    Name    = "cd-net-igw-01"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "Internet access for public subnet"
  }
}

# --- PUBLIC SUBNET ---
# Hosts: NAT instance, Bastion (optional)
resource "aws_subnet" "cd_net_pub_01" {
  vpc_id                  = aws_vpc.cd_net_vpc_01.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name    = "cd-net-pub-01"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "Public subnet for NAT instance"
    Tier    = "Public"
  }
}

# --- PRIVATE SUBNET ---
# Hosts: COREDIRECTIVE_ENGINE instance
resource "aws_subnet" "cd_net_prv_01" {
  vpc_id                  = aws_vpc.cd_net_vpc_01.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name    = "cd-net-prv-01"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "Private subnet for COREDIRECTIVE_ENGINE"
    Tier    = "Private"
  }
}

# --- PUBLIC ROUTE TABLE ---
# Routes traffic from public subnet to Internet Gateway
resource "aws_route_table" "cd_net_rtb_pub" {
  vpc_id = aws_vpc.cd_net_vpc_01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cd_net_igw_01.id
  }

  tags = {
    Name    = "cd-net-rtb-pub"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "Route table for public subnet"
  }
}

# --- PUBLIC SUBNET ASSOCIATION ---
resource "aws_route_table_association" "cd_net_rta_pub" {
  subnet_id      = aws_subnet.cd_net_pub_01.id
  route_table_id = aws_route_table.cd_net_rtb_pub.id
}

# --- PRIVATE ROUTE TABLE ---
# Routes traffic from private subnet to NAT instance (configured in nat.tf)
resource "aws_route_table" "cd_net_rtb_prv" {
  vpc_id = aws_vpc.cd_net_vpc_01.id

  tags = {
    Name    = "cd-net-rtb-prv"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "Route table for private subnet (routes through NAT)"
  }
}

# --- PRIVATE SUBNET ASSOCIATION ---
resource "aws_route_table_association" "cd_net_rta_prv" {
  subnet_id      = aws_subnet.cd_net_prv_01.id
  route_table_id = aws_route_table.cd_net_rtb_prv.id
}

# --- VPC FLOW LOGS (Optional - For Production Monitoring) ---
# Uncomment to enable network traffic logging for security auditing
# Requires CloudWatch Log Group and IAM role

# resource "aws_flow_log" "cd_net_flow_01" {
#   vpc_id          = aws_vpc.cd_net_vpc_01.id
#   traffic_type    = "ALL"
#   iam_role_arn    = aws_iam_role.cd_iam_flowlogs.arn
#   log_destination = aws_cloudwatch_log_group.cd_mon_flowlogs.arn
#
#   tags = {
#     Name    = "cd-net-flow-01"
#     Project = "CD-AWS-AUTOMATION"
#     Purpose = "VPC traffic monitoring"
#   }
# }
