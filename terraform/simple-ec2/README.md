# Simple EC2 Deployment (Quick Start)

## Overview

This is the **quick start** Terraform configuration for deploying the CoreDirective Automation Engine on a single EC2 instance. Use this for demos, testing, and rapid iteration.

**Deployment Time**: ~5 minutes
**Monthly Cost**: ~$135 (t3.xlarge + 100GB gp3 + minimal data transfer)
**Architecture**: Single EC2 instance in default VPC with basic security group

For production deployments with custom VPC, private subnets, and cost-optimized NAT, see [../cd-aws-automation/](../cd-aws-automation/).

---

## Architecture

```
Internet
   ↓
AWS Security Group (cd-alpha-engine-sg)
├─ SSH: Your IP only (port 22)
├─ Emergency: AWS Instance Connect (18.206.107.24/29)
└─ All egress: Allowed
   ↓
EC2 Instance (cd_alpha_engine)
├─ Type: t3.xlarge (4 vCPU, 16GB RAM)
├─ OS: Amazon Linux 2023 (latest AMI)
├─ Storage: 100GB gp3 SSD (3,000 IOPS, 125 MB/s)
├─ Network: Default VPC, public subnet
└─ Access: Cloudflare Tunnel (no direct port exposure)
```

**Services Running**:
- Docker + Docker Compose V2
- PostgreSQL 16 (cd-service-db)
- n8n (cd-service-n8n)
- Ollama + Qwen 3 8B (cd-service-ollama)
- Cloudflare Tunnel (tunnel-cyber-squire)

---

## Prerequisites

1. **AWS Account**: With permissions to create EC2 instances, security groups
2. **AWS CLI**: Configured with credentials (`aws configure`)
3. **Terraform**: Version 1.10+ ([download](https://www.terraform.io/downloads.html))
4. **SSH Key Pair**: Named `cyber-squire-ops` in us-east-1 (or update `variables.tf`)

**Create SSH Key Pair** (if needed):
```bash
aws ec2 create-key-pair \
  --key-name cyber-squire-ops \
  --query 'KeyMaterial' \
  --output text > ~/cyber-squire-ops.pem

chmod 400 ~/cyber-squire-ops.pem
```

---

## Quick Start (5 Steps)

### Step 1: Initialize Terraform

```bash
cd /Users/et/cyber-squire-ops
terraform init
```

Expected output: `Terraform has been successfully initialized!`

### Step 2: Plan Infrastructure

```bash
# Automatically detect your public IP
terraform plan -var="my_ip=$(curl -s checkip.amazonaws.com)"
```

Review the plan. Expected resources:
- 1 Security Group (cd-alpha-engine-sg)
- 1 EC2 Instance (cd_alpha_engine)

### Step 3: Deploy Infrastructure

```bash
terraform apply -var="my_ip=$(curl -s checkip.amazonaws.com)" -auto-approve
```

**Duration**: ~2 minutes

Terraform will output:
```
Outputs:

engine_public_ip = "XX.XXX.XXX.XXX"
n8n_url = "http://XX.XXX.XXX.XXX:5678"
```

### Step 4: SSH to Instance and Bootstrap

```bash
# Get the instance IP from Terraform output
INSTANCE_IP=$(terraform output -raw engine_public_ip)

# SSH to instance
ssh -i ~/cyber-squire-ops.pem ec2-user@$INSTANCE_IP

# Navigate to COREDIRECTIVE_ENGINE directory (created by user_data script)
cd /home/ec2-user/COREDIRECTIVE_ENGINE

# Clone the repository (or upload your config files)
git clone <your-repo> .

# Run the bootstrap script
./cdae-init.sh
```

**Bootstrap Duration**: ~10 minutes (installs Docker, Docker Compose, rclone, hardens system)

### Step 5: Configure Secrets and Launch Stack

```bash
# Copy environment template
cp .env.template .env

# Edit with your real credentials
nano .env

# Launch the Docker Compose stack
docker compose up -d

# Verify all services are running
docker compose ps

# Run health check
./cdae-healthcheck.sh
```

Expected output: All services show `[OK]`

---

## Verification

### Check Services

```bash
# All containers running
docker compose ps
# Expected: 4 services (db, n8n, ollama, tunnel) with status "Up"

# PostgreSQL health
docker exec cd-service-db pg_isready
# Expected: "accepting connections"

# Ollama model loaded
docker exec cd-service-ollama ollama list
# Expected: qwen2.5-coder:7b

# n8n accessible
curl -k http://localhost:5678/healthz
# Expected: {"status":"ok"}
```

### Access n8n Dashboard

**Option 1: Via Cloudflare Tunnel** (recommended)
```
URL: https://[your-tunnel-subdomain].[your-domain].com
```

**Option 2: Via SSH Tunnel** (temporary access)
```bash
ssh -i ~/cyber-squire-ops.pem -L 5678:localhost:5678 ec2-user@$INSTANCE_IP

# Then access: http://localhost:5678
```

---

## Configuration

### Files

- [main.tf](./main.tf) - Provider, security group, EC2 instance
- [variables.tf](./variables.tf) - Input variables (`my_ip`, `key_name`)
- [outputs.tf](./outputs.tf) - Instance IP, n8n URL

### Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `my_ip` | Your public IP for SSH access | Yes | - |
| `key_name` | EC2 key pair name | No | `cyber-squire-ops` |

**Override variables**:
```bash
terraform apply \
  -var="my_ip=203.0.113.0" \
  -var="key_name=my-custom-key"
```

---

## Cost Breakdown

| Resource | Type | Monthly Cost |
|----------|------|--------------|
| EC2 Instance | t3.xlarge (on-demand) | $122 |
| EBS Volume | 100GB gp3 | $8 |
| Data Transfer | ~50GB outbound | $5 |
| **Total** | | **~$135** |

**Cost Optimization Tips**:
- Use Reserved Instances for 1-year commitment: $73/mo (40% savings)
- Use Spot Instances for non-critical workloads: $36/mo (70% savings)
- Reduce EBS to 50GB if not storing large datasets: Save $4/mo

---

## Maintenance

### Update AMI

```bash
# Latest Amazon Linux 2023 AMI is fetched automatically via data source
terraform plan
terraform apply
```

### Backup Strategy

**Terraform State**:
```bash
# Local state is stored at: terraform.tfstate
# IMPORTANT: Back this up or migrate to S3 backend

# Backup command:
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)
```

**Database Backups**: See [../../docs/PRIVATE_OPERATIONS_MANUAL.md](../../docs/PRIVATE_OPERATIONS_MANUAL.md) for rclone + Google Drive backup procedure.

### Security Updates

```bash
# SSH to instance
ssh -i ~/cyber-squire-ops.pem ec2-user@$INSTANCE_IP

# Update packages
sudo dnf update -y

# Restart Docker if kernel updated
sudo systemctl restart docker

# Restart stack
cd /home/ec2-user/COREDIRECTIVE_ENGINE
docker compose restart
```

---

## Troubleshooting

### SSH Connection Refused

**Cause**: Your IP changed (dynamic IP from ISP)

**Fix**:
```bash
# Get your current IP
curl checkip.amazonaws.com

# Update security group
terraform apply -var="my_ip=$(curl -s checkip.amazonaws.com)"
```

### Services Won't Start

**Cause**: Insufficient memory (OOM)

**Fix**:
```bash
# Check memory usage
free -h

# Check container resource limits
docker stats

# If PostgreSQL or Ollama are using > 90% of allocated memory:
# Edit docker-compose.yaml and reduce memory limits
nano docker-compose.yaml

docker compose restart
```

### n8n Dashboard Unreachable

**Cause**: Cloudflare Tunnel not running

**Fix**:
```bash
# Check tunnel status
docker logs tunnel-cyber-squire --tail=50

# Restart tunnel
docker compose restart tunnel-cyber-squire

# Alternative: Use SSH tunnel (see Verification section above)
```

---

## Upgrade to Production Architecture

When you're ready for:
- Custom VPC with public/private subnet isolation
- Self-managed NAT instance ($28/mo savings vs AWS NAT Gateway)
- S3 + KMS backend for shared Terraform state
- CD-Standard naming conventions

**See**: [../cd-aws-automation/README.md](../cd-aws-automation/README.md)

---

## Cleanup

**Destroy all infrastructure** (irreversible):

```bash
terraform destroy -var="my_ip=$(curl -s checkip.amazonaws.com)"
```

**Duration**: ~2 minutes

**What gets deleted**:
- EC2 instance (cd_alpha_engine)
- Security group (cd-alpha-engine-sg)
- EBS volume (attached to instance)

**NOT deleted** (manual cleanup required):
- Terraform state file (`terraform.tfstate`)
- SSH key pair (`cyber-squire-ops`)
- Cloudflare Tunnel (must delete from Cloudflare dashboard)

---

## Security Notes

**What's Protected**:
- SSH access restricted to your IP + AWS Instance Connect
- n8n access via Cloudflare Tunnel (no direct public exposure)
- SELinux in enforcing mode (container confinement)
- Secrets stored in `.env` (git-ignored, 600 permissions)

**What's NOT Protected** (acceptable for demos, fix for production):
- EC2 instance in public subnet (no private subnet isolation)
- Default VPC (shared with other AWS resources)
- Local Terraform state (no S3 backend encryption)
- No VPC Flow Logs (no network traffic monitoring)
- EBS volume unencrypted (data-at-rest not encrypted)

For production-grade security, use [../cd-aws-automation/](../cd-aws-automation/).

---

## Next Steps

1. **Review full documentation**: [../../docs/TERRAFORM_DEPLOYMENT_GUIDE.md](../../docs/TERRAFORM_DEPLOYMENT_GUIDE.md)
2. **Understand architecture**: [../../docs/ARCHITECTURE_DIAGRAMS.md](../../docs/ARCHITECTURE_DIAGRAMS.md)
3. **Configure n8n workflows**: See [../../COREDIRECTIVE_ENGINE/](../../COREDIRECTIVE_ENGINE/)
4. **Set up monitoring**: [../../docs/Technical_Vault.md#monitoring](../../docs/Technical_Vault.md)

---

## Support

**Issues?** Check:
- [Troubleshooting section](#troubleshooting) above
- [docs/ADHD_Runbook.md](../../docs/ADHD_Runbook.md) - Copy-paste operational commands
- [docs/Technical_Vault.md](../../docs/Technical_Vault.md) - Deep-dive system specs

**Security concerns?** Review [../../docs/PRIVATE_OPERATIONS_MANUAL.md](../../docs/PRIVATE_OPERATIONS_MANUAL.md) (local only, git-ignored)

---

**Last Updated**: 2026-01-30
**Terraform Version**: 1.10+
**AWS Region**: us-east-1
**Deployment**: Simple EC2 (Quick Start)
