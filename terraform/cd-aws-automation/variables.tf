# --- INPUT VARIABLES (CD-AWS-AUTOMATION) ---
# Configuration parameters for production-grade infrastructure

# --- AWS REGION ---
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# --- NETWORK CONFIGURATION ---

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet (NAT instance)"
  type        = string
  default     = "10.0.10.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet (COREDIRECTIVE_ENGINE)"
  type        = string
  default     = "10.0.20.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnets"
  type        = string
  default     = "us-east-1a"
}

# --- SECURITY CONFIGURATION ---

variable "my_ip" {
  description = "Your public IP address for SSH access (CIDR format: X.X.X.X/32)"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.my_ip))
    error_message = "my_ip must be a valid IP address in CIDR format (e.g., 203.0.113.45/32)"
  }
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = "cyber-squire-ops"
}

# --- NAT INSTANCE CONFIGURATION ---

variable "nat_instance_type" {
  description = "Instance type for NAT instance (cost-optimized)"
  type        = string
  default     = "t3.nano"

  validation {
    condition     = contains(["t3.nano", "t3.micro", "t4g.nano", "t4g.micro"], var.nat_instance_type)
    error_message = "NAT instance type must be one of: t3.nano, t3.micro, t4g.nano, t4g.micro (cost-optimized options)"
  }
}

# --- COREDIRECTIVE_ENGINE INSTANCE CONFIGURATION ---

variable "cdae_instance_type" {
  description = "Instance type for COREDIRECTIVE_ENGINE (must support 16GB RAM for Ollama + PostgreSQL + n8n)"
  type        = string
  default     = "t3.xlarge"

  validation {
    condition     = contains(["t3.xlarge", "t3.2xlarge", "t3a.xlarge", "t3a.2xlarge", "m5.xlarge", "m5.2xlarge"], var.cdae_instance_type)
    error_message = "CDAE instance type must support at least 16GB RAM"
  }
}

variable "cdae_volume_size" {
  description = "Root volume size in GB for COREDIRECTIVE_ENGINE (Docker volumes + Ollama models)"
  type        = number
  default     = 100

  validation {
    condition     = var.cdae_volume_size >= 50 && var.cdae_volume_size <= 500
    error_message = "Volume size must be between 50GB (minimum for Docker + Ollama) and 500GB"
  }
}

# --- TAGS ---

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "CD-AWS-AUTOMATION"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

# --- OPTIONAL: CLOUDFLARE TUNNEL CONFIGURATION ---
# Uncomment if you want to pass Cloudflare Tunnel token as a variable

# variable "cloudflare_tunnel_token" {
#   description = "Cloudflare Tunnel token for n8n access (sensitive)"
#   type        = string
#   sensitive   = true
#   default     = ""
# }

# --- NOTES ---
#
# Required Variables:
#   - my_ip: Your public IP for SSH access
#
# Optional Variables:
#   - All others have sensible defaults
#
# Usage:
#   terraform plan -var="my_ip=$(curl -s checkip.amazonaws.com)/32"
#   terraform apply -var="my_ip=203.0.113.45/32" -var="cdae_instance_type=t3.2xlarge"
#
# Or create terraform.tfvars:
#   my_ip = "203.0.113.45/32"
#   cdae_instance_type = "t3.2xlarge"
#   environment = "staging"
