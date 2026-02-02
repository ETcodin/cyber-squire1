# --- NAT INSTANCE (CD-Standard Naming) ---
# Self-managed NAT instance replaces AWS NAT Gateway
# Cost: $3.80/mo (t3.nano) vs $32.85/mo (managed NAT gateway)
# Annual savings: $348

# --- AMI: Amazon Linux 2023 (Latest) ---
# Free-tier eligible, optimized for AWS, automatic security patches
data "aws_ami" "cd_nat_al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# --- NAT INSTANCE ---
# Smallest viable instance type for NAT functionality
resource "aws_instance" "cd_srv_nat_01" {
  ami                    = data.aws_ami.cd_nat_al2023.id
  instance_type          = var.nat_instance_type
  subnet_id              = aws_subnet.cd_net_pub_01.id
  vpc_security_group_ids = [aws_security_group.cd_sec_nat_01.id]
  key_name               = var.key_name

  # CRITICAL: Disable source/destination check for NAT functionality
  # Without this, AWS will drop forwarded packets
  source_dest_check = false

  # Assign public IP for internet access
  associate_public_ip_address = true

  # Bootstrap script: Configure NAT functionality
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    dnf update -y

    # Enable IP forwarding (required for NAT)
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p

    # Configure iptables for NAT (IP masquerading)
    # This translates private IPs to the NAT instance's public IP
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

    # Make iptables rules persistent across reboots
    iptables-save > /etc/sysconfig/iptables

    # Enable iptables service
    systemctl enable iptables
    systemctl start iptables

    # Install useful diagnostic tools
    dnf install -y tcpdump net-tools bind-utils
  EOF

  # EBS root volume (minimal storage needed for NAT)
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name                = "cd-srv-nat-01"
    Project             = "CD-AWS-AUTOMATION"
    Purpose             = "Self-managed NAT gateway"
    Cost-Savings        = "$28-per-month"
    Alternative         = "Replaces AWS NAT Gateway"
    Monthly-Cost        = "$3.80-4.50"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- PRIVATE ROUTE: DEFAULT TRAFFIC TO NAT ---
# Routes all outbound traffic from private subnet through NAT instance
resource "aws_route" "cd_net_route_prv_nat" {
  route_table_id         = aws_route_table.cd_net_rtb_prv.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.cd_srv_nat_01.primary_network_interface_id
}

# --- COST ANALYSIS (Documentation) ---
# AWS NAT Gateway Cost (Monthly):
#   - Hourly charge:     $0.045/hr × 730 hrs = $32.85
#   - Data processing:   $0.045/GB × 100 GB  = $4.50
#   - Total:             $37.35/month
#
# Self-Managed NAT (t3.nano) Cost (Monthly):
#   - Instance:          $0.0052/hr × 730 hrs = $3.80
#   - Data transfer:     $0 (included in EC2 data transfer)
#   - EBS 8GB:           $0.80 (gp3 storage)
#   - Total:             $4.60/month
#
# Monthly Savings:       $37.35 - $4.60 = $32.75
# Annual Savings:        $32.75 × 12 = $393
#
# Trade-offs:
#   - Availability: Single-AZ (NAT Gateway supports multi-AZ)
#   - Throughput: ~5 Gbps (NAT Gateway: up to 100 Gbps)
#   - Management: Manual updates (NAT Gateway: fully managed)
#
# Acceptable for:
#   - Single-instance workloads
#   - Development/staging environments
#   - Cost-constrained deployments
#   - Low-to-moderate traffic (<10 GB/day)
