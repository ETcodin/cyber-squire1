# --- EC2 INSTANCE (CD-Standard Naming) ---
# COREDIRECTIVE_ENGINE instance in private subnet with NAT-based internet access

# --- PROVIDER ---
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- AMI: Amazon Linux 2023 (Latest) ---
data "aws_ami" "cd_ec2_al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# --- COREDIRECTIVE_ENGINE INSTANCE ---
# Hosts: PostgreSQL, n8n, Ollama, Cloudflare Tunnel
resource "aws_instance" "cd_srv_cdae_01" {
  ami                    = data.aws_ami.cd_ec2_al2023.id
  instance_type          = var.cdae_instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.cd_net_prv_01.id
  vpc_security_group_ids = [aws_security_group.cd_sec_cdae_01.id]

  # Private subnet: No public IP (internet via NAT)
  associate_public_ip_address = false

  # EBS root volume: 100GB gp3 for Docker volumes + Ollama models
  root_block_device {
    volume_size = var.cdae_volume_size
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
    encrypted   = true

    tags = {
      Name    = "cd-srv-cdae-01-root"
      Project = "CD-AWS-AUTOMATION"
    }
  }

  # Bootstrap script: Install Docker, Docker Compose, create directory structure
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    dnf update -y

    # Install Docker
    dnf install -y docker rclone

    # Enable and start Docker
    systemctl enable --now docker

    # Add ec2-user to docker group
    usermod -aG docker ec2-user

    # Install Docker Compose V2
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # Create directory structure (CD-Standard)
    mkdir -p /home/ec2-user/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
    chown -R ec2-user:ec2-user /home/ec2-user/COREDIRECTIVE_ENGINE

    # Install useful diagnostic tools
    dnf install -y tcpdump net-tools bind-utils htop git

    # Configure timezone (optional, adjust as needed)
    timedatectl set-timezone America/New_York
  EOF

  # Metadata options (IMDSv2 required for security)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "cd-srv-cdae-01"
    Project = "CD-AWS-AUTOMATION"
    Purpose = "COREDIRECTIVE_ENGINE (n8n + PostgreSQL + Ollama)"
    Subnet  = "Private"
  }

  lifecycle {
    create_before_destroy = false
  }
}

# --- ELASTIC IP FOR NAT INSTANCE (Optional) ---
# Uncomment to allocate a static IP for the NAT instance
# Useful if you need a stable IP for outbound connections (e.g., IP whitelisting)

# resource "aws_eip" "cd_net_eip_nat" {
#   domain   = "vpc"
#   instance = aws_instance.cd_srv_nat_01.id
#
#   tags = {
#     Name    = "cd-net-eip-nat"
#     Project = "CD-AWS-AUTOMATION"
#     Purpose = "Static IP for NAT instance"
#   }
# }

# --- NOTES ---
# SSH Access:
#   Option 1: Jump through NAT instance
#     ssh -i key.pem -J ec2-user@NAT_PUBLIC_IP ec2-user@CDAE_PRIVATE_IP
#
#   Option 2: Use AWS Systems Manager Session Manager (recommended)
#     aws ssm start-session --target INSTANCE_ID
#     (Requires SSM agent and IAM role with SSM permissions)
#
# Internet Access:
#   - All outbound traffic routes through NAT instance (cd-srv-nat-01)
#   - Inbound traffic: None (private subnet, no public IP)
#   - n8n access: Only via Cloudflare Tunnel (no direct port exposure)
#
# Resource Allocation:
#   - PostgreSQL: 4GB RAM limit
#   - n8n: 2GB RAM limit
#   - Ollama: 7.5GB RAM limit
#   - System: ~2.5GB available
#   - Total: 16GB (t3.xlarge)
#
# Cost Breakdown (Monthly):
#   - t3.xlarge:     $122
#   - 100GB gp3:     $8
#   - Data transfer: ~$5
#   - NAT instance:  $4
#   - Total:         $139/month
