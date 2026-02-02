# --- PROVIDER ---
provider "aws" {
  region = "us-east-1"
}

# --- DYNAMIC AMI DATA SOURCE ---
# Amazon Linux 2023 in us-east-1 (latest x86_64 HVM)
data "aws_ami" "al2023" {
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
}

# --- THE PERIMETER: ZERO-TRUST ---
resource "aws_security_group" "cd_engine_sg" {
  name        = "cd-alpha-engine-sg"
  description = "Managed via Terraform - Zero Trust for CD-AE"

  # 1. EMERGENCY SSH: Restricted to your Current IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"] 
  }

  # 2. EMERGENCY "BACKDOOR": AWS Instance Connect (Console Access)
  # This CIDR is specific to the us-east-1 EC2 Instance Connect Service
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["18.206.107.24/29"] 
  }

  # 3. N8N VIA CLOUDFLARE TUNNEL ONLY (No Direct Public Access)
  # Tunnel absorbs inbound traffic; this rule is DEPRECATED post-tunnel-deployment
  # Commented out for production hardening
  # ingress {
  #   from_port   = 5678
  #   to_port     = 5678
  #   protocol    = "tcp"
  #   cidr_blocks = ["${var.my_ip}/32"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- THE ENGINE: 16GB RAM + PERFORMANCE SSD ---
resource "aws_instance" "cd_alpha_engine" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.xlarge" # 16GB RAM / 4 vCPU
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.cd_engine_sg.id]

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }

  # --- AUTOMATED BOOTSTRAP (Zero Manual Labor) ---
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker rclone
              systemctl enable --now docker
              usermod -aG docker ec2-user

              # Install Docker Compose V2
              mkdir -p /usr/local/lib/docker/cli-plugins
              curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # Create Directory Structure (Naming Game)
              mkdir -p /home/ec2-user/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
              chown -R ec2-user:ec2-user /home/ec2-user/COREDIRECTIVE_ENGINE
              EOF

  tags = {
    Name = "CD-Alpha-Engine"
    Project = "Operation-Nuclear"
  }
}