# --- SECURITY GROUPS (CD-Standard Naming) ---
# Zero-trust network security for CD-AWS-AUTOMATION infrastructure

# --- NAT INSTANCE SECURITY GROUP ---
# Allows traffic from private subnet, SSH from your IP
resource "aws_security_group" "cd_sec_nat_01" {
  name        = "cd-sec-nat-01"
  description = "Security group for self-managed NAT instance (CD-Standard)"
  vpc_id      = aws_vpc.cd_net_vpc_01.id

  # Allow SSH from your IP (for NAT instance management)
  ingress {
    description = "SSH from operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  # Allow SSH from AWS Instance Connect (emergency backdoor)
  ingress {
    description = "SSH from AWS Instance Connect (us-east-1)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["18.206.107.24/29"]
  }

  # Allow all inbound from private subnet (NAT function)
  ingress {
    description = "All traffic from private subnet"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  ingress {
    description = "UDP traffic from private subnet"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  ingress {
    description = "ICMP from private subnet (ping diagnostics)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.private_subnet_cidr]
  }

  # Allow all outbound (NAT function)
  egress {
    description = "All outbound traffic (NAT to internet)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "cd-sec-nat-01"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "NAT instance security group"
  }
}

# --- COREDIRECTIVE_ENGINE SECURITY GROUP ---
# Restricts access to private subnet only
resource "aws_security_group" "cd_sec_cdae_01" {
  name        = "cd-sec-cdae-01"
  description = "Security group for COREDIRECTIVE_ENGINE in private subnet (CD-Standard)"
  vpc_id      = aws_vpc.cd_net_vpc_01.id

  # Allow SSH from NAT instance (jump host)
  ingress {
    description     = "SSH from NAT instance"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.cd_sec_nat_01.id]
  }

  # Allow SSH from your IP (if using VPN or direct connection)
  # Comment out if you only want SSH via NAT jump host
  ingress {
    description = "SSH from operator IP (optional, for VPN/direct access)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  # Allow all traffic within VPC (for inter-service communication)
  ingress {
    description = "All traffic from VPC CIDR"
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound (Docker pulls, package updates, n8n webhooks)
  egress {
    description = "All outbound traffic (via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "cd-sec-cdae-01"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "COREDIRECTIVE_ENGINE security group"
  }
}

# --- SECURITY GROUP OUTPUTS (for verification) ---
# Used for terraform output and debugging
output "nat_security_group_id" {
  description = "Security group ID for NAT instance"
  value       = aws_security_group.cd_sec_nat_01.id
}

output "cdae_security_group_id" {
  description = "Security group ID for COREDIRECTIVE_ENGINE"
  value       = aws_security_group.cd_sec_cdae_01.id
}

# --- SECURITY NOTES ---
# 1. NAT instance allows SSH from your IP only (not 0.0.0.0/0)
# 2. CDAE instance is in private subnet (no direct internet access)
# 3. All outbound traffic from CDAE goes through NAT instance
# 4. No inbound rules for HTTP/HTTPS (use Cloudflare Tunnel for n8n access)
# 5. ICMP allowed for network diagnostics (ping, traceroute)
#
# Attack Surface:
#   - SSH to NAT: Restricted to your IP + AWS Instance Connect
#   - SSH to CDAE: Only via NAT jump host (or your IP if VPN)
#   - n8n Dashboard: Only via Cloudflare Tunnel (no direct port exposure)
#
# Compliance:
#   - CIS AWS Foundations Benchmark: Section 5.1 (Security Groups)
#   - NIST 800-53: SC-7 (Boundary Protection)
