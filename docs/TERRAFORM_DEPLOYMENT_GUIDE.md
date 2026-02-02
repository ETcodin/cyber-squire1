# CoreDirective Alpha-Engine (CD-AE) - Terraform Deployment Guide

**Version:** 1.0.0-ALPHA  
**Target Date:** January 30, 2026  
**Infrastructure:** AWS EC2 t3.xlarge (Amazon Linux 2023 / RHEL 9.x)  
**Operation:** Operation Nuclear (C-suite outreach campaign)  

---

## ARCHITECTURE OVERVIEW

This Terraform stack deploys the **"Hard Shell"** infrastructure for CD-AE:

### The Three Pillars (In Infrastructure Terms)

1. **Brain:** Ollama + Qwen 3 8B running in Docker containers
2. **Orchestrator:** n8n workflow automation engine with PostgreSQL backend
3. **Memory:** PostgreSQL 16 database with 4GB hard memory cap

### AWS Resources Deployed

| Resource | Name | Specification | Purpose |
|----------|------|---------------|---------| 
| EC2 Instance | cd-alpha-engine | t3.xlarge (4vCPU, 16GB RAM) | Compute host for CD-AE stack |
| Storage | root_block_device | 100GB gp3 (3000 IOPS, 125 MB/s) | High-performance SSD for database + AI |
| Security Group | cd-alpha-engine-sg | Zero-trust ingress rules | Perimeter defense with IP restrictions |
| AMI Source | al2023-ami | Dynamic lookup (latest Amazon Linux 2023) | OS selection without hardcoded AMI IDs |

---

## PREREQUISITES

**Before deploying, ensure you have:**

1. **AWS Account** with programmatic access
2. **AWS CLI** configured locally: `aws configure`
3. **Terraform** installed (v1.0+): `terraform --version`
4. **EC2 Key Pair** created in AWS (default name: `cyber-squire-key`)
5. **Your public IP address** (for SSH restricted access)

### Get Your Public IP

```bash
# Option 1: Using curl
curl -s http://checkip.amazonaws.com

# Option 2: Using AWS CLI (if configured)
curl -s https://ifconfig.me

# Option 3: Using native command
dig +short myip.opendns.com @resolver1.opendns.com
```

**IMPORTANT:** Save this IP - you'll need it during deployment.

---

## FILE STRUCTURE

```
/Users/et/cyber-squire-ops/
├── main.tf                           ← EC2 + Security Group + User Data
├── variables.tf                      ← Input variables (my_ip, key_name)
├── outputs.tf                        ← Outputs (engine_public_ip, n8n_url)
├── terraform.tfstate                 ← State file (stores deployed resources)
├── terraform.tfstate.backup          ← State backup (automatic)
├── .terraform/                       ← Terraform provider cache
└── docs/TERRAFORM_DEPLOYMENT_GUIDE.md  ← This file
```

---

## DEPLOYMENT WORKFLOW

### Step 1: Navigate to Project Root

```bash
cd /Users/et/cyber-squire-ops
```

### Step 2: Initialize Terraform

Terraform downloads AWS provider and prepares the working directory.

```bash
terraform init
```

**Expected output:**
```
Initializing the backend...
Initializing provider plugins...
...
Terraform has been successfully configured!
```

### Step 3: Validate Configuration

Syntax check before deployment.

```bash
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### Step 4: Generate Plan (DRY RUN)

Preview all resources that will be created without deploying.

**Method A: Auto-detect your IP**
```bash
terraform plan -var="my_ip=$(curl -s http://checkip.amazonaws.com)"
```

**Method B: Manually specify IP**
```bash
terraform plan -var="my_ip=203.0.113.45"  # Replace with your IP
```

**Expected output:**
```
Terraform will perform the following actions:

  # aws_instance.cd_alpha_engine will be created
  + resource "aws_instance" "cd_alpha_engine" {
      + ami                    = "ami-..." (dynamic)
      + instance_type          = "t3.xlarge"
      + key_name               = "cyber-squire-key"
      + public_ip              = (known after apply)
      ...
    }

  # aws_security_group.cd_engine_sg will be created
  + resource "aws_security_group" "cd_engine_sg" {
      ...
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

**Review the plan carefully.** If something looks wrong, stop here and fix variables.tf.

### Step 5: Deploy Infrastructure

Execute the plan and create AWS resources. This takes 2-3 minutes.

**Method A: Auto-detect your IP (Recommended)**
```bash
terraform apply -var="my_ip=$(curl -s http://checkip.amazonaws.com)" --auto-approve
```

**Method B: Manually specify IP**
```bash
terraform apply -var="my_ip=203.0.113.45" --auto-approve
```

**Expected output (after 2-3 min):**
```
Apply complete! Resources have been created.

Outputs:

engine_public_ip = "54.123.45.67"
n8n_url = "http://54.123.45.67:5678"
```

### Step 6: Verify EC2 Bootstrap

The instance is running, but Docker containers are still initializing. Wait 3-5 minutes for bootstrap to complete.

```bash
# SSH into the instance
ssh -i cyber-squire-key.pem ec2-user@<engine_public_ip>

# Check if Docker is running
docker ps

# Check bootstrap progress
tail -20 /var/log/cloud-init-output.log
```

**Expected sequence:**
1. `docker ps` shows no containers yet (still initializing)
2. After 5 minutes, log shows "usermod -aG docker" completed
3. You can now proceed to COREDIRECTIVE_ENGINE setup

---

## POST-DEPLOYMENT BOOTSTRAP

Once EC2 is healthy, CD-AE stack is NOT yet running. You must deploy the Docker containers.

### SSH into the Instance

```bash
ssh -i cyber-squire-key.pem ec2-user@<engine_public_ip>
```

### Deploy COREDIRECTIVE_ENGINE Stack

Follow the **RHEL_System_Init.md** workflow starting at **Phase 2: CD-AE Deployment**.

Quick recap:

```bash
# 1. Navigate to project home
cd /home/ec2-user/COREDIRECTIVE_ENGINE

# 2. Create .env from template (populate with secrets)
cp .env.template .env
nano .env  # Edit database passwords, API keys, etc.

# 3. Upload docker-compose.yaml (from COREDIRECTIVE_ENGINE/)
# (Download locally first: scp cyber-squire-key.pem ec2-user@IP:/home/ec2-user/... )

# 4. Start CD-AE stack
docker compose up -d

# 5. Verify all containers are healthy
docker compose ps

# 6. Access n8n
open http://<engine_public_ip>:5678
```

---

## SECURITY FEATURES

### The Three-Layer Defense

**Layer 1: AWS Security Group (Zero-Trust Ingress)**
- SSH (port 22): Restricted to your IP + AWS Instance Connect emergency backdoor
- n8n (port 5678): Restricted to your IP only
- Egress: Full internet access (for Docker pulls, API calls)

**Layer 2: Cloudflare Tunnel (Post-Deployment)**
- Replaces direct public IP exposure
- Authenticates access via Cloudflare dashboard
- No SSH/n8n ports open to public internet

**Layer 3: Database Credentials**
- PostgreSQL password stored in `.env` (git-ignored)
- n8n encryption key stored in `.env`
- Ollama API is internal-only (no public exposure)

### If Your IP Changes

**Option A: Update Security Group via Terraform**
```bash
terraform apply -var="my_ip=$(curl -s http://checkip.amazonaws.com)" --auto-approve
```

**Option B: Use AWS Instance Connect (Emergency Backdoor)**
- Open AWS Console → EC2 → Instances → cd-alpha-engine
- Click "Connect" → EC2 Instance Connect tab
- Browser-based terminal (no SSH key needed)

---

## VARIABLE REFERENCE

### Customize Deployment

Edit `variables.tf` BEFORE running `terraform apply`:

```terraform
variable "my_ip" {
  description = "Your current public IP for restricted SSH/n8n access"
  type        = string
  # Example: "203.0.113.45/32"
}

variable "key_name" {
  description = "The name of your existing EC2 Key Pair (e.g., cyber-squire-key)"
  type        = string
  default     = "cyber-squire-key"  # Change if using different key
}
```

### Override at Deployment Time

```bash
# Use different key pair
terraform apply \
  -var="my_ip=$(curl -s http://checkip.amazonaws.com)" \
  -var="key_name=my-other-key" \
  --auto-approve
```

---

## OUTPUTS & NEXT STEPS

After successful deployment, Terraform outputs:

```
engine_public_ip = "54.123.45.67"
n8n_url = "http://54.123.45.67:5678"
```

### Immediate Next Steps

1. **SSH into instance** and verify Docker is running
2. **Deploy CD-AE stack** using COREDIRECTIVE_ENGINE/docker-compose.yaml
3. **Configure .env** with database passwords and API keys
4. **Access n8n** at http://54.123.45.67:5678
5. **Setup Cloudflare Tunnel** for zero-trust remote access (optional but recommended)
6. **Configure Operation Nuclear** Notion database trigger workflow

---

## TROUBLESHOOTING

### Issue: "Error: No valid credential sources found"

**Cause:** AWS credentials not configured locally.

**Fix:**
```bash
aws configure
# Enter: AWS Access Key ID
# Enter: AWS Secret Access Key
# Enter: Region (us-east-1)
# Enter: Output format (json)
```

### Issue: "KeyError: my_ip"

**Cause:** Did not provide `-var="my_ip=..."` during plan/apply.

**Fix:**
```bash
# Re-run with explicit IP
terraform apply -var="my_ip=203.0.113.45" --auto-approve
```

### Issue: SSH Key Permission Denied

**Cause:** Key file has wrong permissions (too open).

**Fix:**
```bash
chmod 600 cyber-squire-key.pem
ssh -i cyber-squire-key.pem ec2-user@<IP>
```

### Issue: EC2 Instance Created but Docker Not Running

**Cause:** Bootstrap script still executing (takes 3-5 minutes).

**Fix:**
```bash
ssh -i cyber-squire-key.pem ec2-user@<IP>
tail -100 /var/log/cloud-init-output.log
# Wait for "usermod: user already in group docker" or similar success message
```

### Issue: Can't Access n8n at http://IP:5678

**Cause:** 
- Bootstrap not complete (5+ min passed?)
- Docker containers not started yet
- Security group port 5678 not open to your IP

**Fix:**
```bash
# SSH and check containers
ssh -i cyber-squire-key.pem ec2-user@<IP>
docker compose ps

# If no containers, deploy them
cd /home/ec2-user/COREDIRECTIVE_ENGINE
docker compose up -d
```

---

## STATE MANAGEMENT

### terraform.tfstate

Terraform stores all deployed resource details in `terraform.tfstate`. This is **NOT a backup** - it's a runtime reference.

**DO NOT:**
- Commit to git
- Modify manually
- Delete (or you lose state tracking)

**DO:**
- Backup regularly: `cp terraform.tfstate terraform.tfstate.backup`
- Store in S3 for team deployments (advanced)
- Keep in git-ignored directory

### Destroying Infrastructure

If you need to tear down the entire CD-AE environment:

```bash
terraform destroy -var="my_ip=$(curl -s http://checkip.amazonaws.com)" --auto-approve
```

**WARNING:** This deletes the EC2 instance and all Docker containers. Data in PostgreSQL is LOST.

---

## ADVANCED: TERRAFORM STATE BACKEND (S3)

For team deployments, store state in S3 instead of local .tfstate file.

Create `backend.tf`:
```terraform
terraform {
  backend "s3" {
    bucket         = "cd-ae-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
```

Then run:
```bash
terraform init  # Terraform will prompt to migrate state to S3
```

---

## MONITORING & ALERTS

After deployment, monitor your running instances:

```bash
# AWS CLI: List running instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"

# AWS Console: https://console.aws.amazon.com/ec2/
```

### Set CloudWatch Alarms (Optional)

For production Operation Nuclear campaigns, configure CloudWatch alerts on:
- CPU usage > 80%
- Memory usage > 14GB (leaving 2GB OS buffer)
- Ollama container status (health check)
- PostgreSQL connection count

---

## COST ESTIMATION

**Monthly AWS Bill (Estimated)**

| Resource | Cost/Month | Notes |
|----------|-----------|-------|
| t3.xlarge compute | $122 | On-demand, us-east-1 |
| 100GB gp3 SSD | $8 | 3000 IOPS, 125 MB/s throughput |
| Data transfer (egress) | $0-15 | Depends on Google Drive sync volume |
| **Total** | **~$130-150/month** | ✅ Within $120k annual budget |

**Cost Optimization Tips:**
- Use **t3.medium** instead of t3.xlarge to reduce to $40/month (but may be too slow for Qwen 3)
- Use **Spot Instances** for non-critical workloads (saves 70%)
- Enable **Auto-stopping** if not running 24/7

---

## VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0-ALPHA | Jan 30, 2026 | Initial CD-AE Terraform stack |
| 1.0.1 | TBD | Add S3 state backend, CloudWatch alarms |
| 2.0.0 | TBD | Multi-region failover, auto-scaling |

---

## SUPPORT & ESCALATION

**If deployment fails:**
1. Check error message in terminal output
2. Review Troubleshooting section above
3. Check AWS Console → EC2 → Events for instance-level issues
4. Review cloud-init logs: `ssh ... tail -100 /var/log/cloud-init-output.log`

**For persistence:**
- Save all Terraform outputs to a secure note
- Backup terraform.tfstate daily
- Document any manual changes to .env or docker-compose.yaml

---

**Next Document:** [RHEL_System_Init.md](RHEL_System_Init.md) - System initialization after Terraform deployment  
**Related Docs:** [Technical_Vault.md](Technical_Vault.md) | [ADHD_Runbook.md](ADHD_Runbook.md)  
**Maintained By:** Emmanuel Tigoue  
**Last Updated:** January 30, 2026
