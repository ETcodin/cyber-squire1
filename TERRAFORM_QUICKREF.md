# CD-AE Terraform Quick Reference

## Files Deployed

✅ **main.tf** (89 lines)
- AWS provider configuration
- Dynamic AMI data source (latest Amazon Linux 2023)
- Zero-trust security group (SSH + n8n webhooks restricted to your IP)
- EC2 t3.xlarge instance with 100GB gp3 SSD
- Automated bootstrap via user_data script

✅ **variables.tf** (10 lines)
- `my_ip`: Your public IP (required at deployment time)
- `key_name`: EC2 key pair name (default: cyber-squire-key)

✅ **outputs.tf** (7 lines)
- `engine_public_ip`: Public IP of your CD-AE instance
- `n8n_url`: Direct HTTP URL to n8n dashboard

---

## Deployment Checklist

**Before Running Terraform:**
- [ ] AWS CLI configured locally: `aws configure`
- [ ] EC2 Key Pair created in AWS: "cyber-squire-key"
- [ ] Know your public IP: `curl -s http://checkip.amazonaws.com`
- [ ] Terraform installed: `terraform --version`

**Execution Steps:**
```bash
cd /Users/et/cyber-squire-ops

# 1. Initialize (one-time)
terraform init

# 2. Validate syntax
terraform validate

# 3. Preview (dry-run)
terraform plan -var="my_ip=$(curl -s http://checkip.amazonaws.com)"

# 4. Deploy (takes 2-3 min)
terraform apply -var="my_ip=$(curl -s http://checkip.amazonaws.com)" --auto-approve

# 5. Note outputs
#    engine_public_ip = "54.123.45.67"
#    n8n_url = "http://54.123.45.67:5678"

# 6. SSH to instance
ssh -i cyber-squire-key.pem ec2-user@54.123.45.67

# 7. Wait 3-5 minutes for bootstrap completion
tail -20 /var/log/cloud-init-output.log

# 8. Deploy CD-AE Docker stack (follow RHEL_System_Init.md Phase 2)
```

---

## What Gets Created

| AWS Resource | Specification | Purpose |
|--------------|---------------|---------|
| EC2 Instance | t3.xlarge (4 vCPU, 16GB RAM) | Compute host for Three Pillars (Brain/Orchestrator/Memory) |
| EBS Volume | 100GB gp3 (3000 IOPS, 125 MB/s) | High-performance SSD for PostgreSQL + AI workloads |
| Security Group | cd-alpha-engine-sg | Zero-trust firewall (SSH + n8n restricted to your IP) |
| AMI | Latest Amazon Linux 2023 | RHEL 9.x-compatible OS with dnf package manager |

---

## Security Model

**Three Layers of Defense:**

1. **AWS Security Group** (Perimeter)
   - SSH (port 22): Your IP only + AWS Instance Connect backdoor
   - n8n (port 5678): Your IP only
   - All egress allowed (Docker pulls, API calls)

2. **Cloudflare Tunnel** (Application Layer - Post-deployment)
   - Replace direct public IP access
   - Zero-trust authentication
   - Run after `docker compose up`

3. **Database Credentials** (Data Layer)
   - PostgreSQL password in `.env` (git-ignored)
   - n8n encryption key in `.env`
   - Ollama API internal-only

---

## Cost Estimate

**Monthly AWS Burn Rate:**
- t3.xlarge compute: ~$122
- 100GB gp3 SSD: ~$8
- Data transfer: ~$5-15
- **Total: ~$135-150/month** (within Operation Nuclear budget)

---

## Post-Deployment Workflow

After `terraform apply` succeeds:

1. **SSH into instance** (3-5 min after creation, bootstrap still running)
2. **Wait for bootstrap** to complete (`tail /var/log/cloud-init-output.log`)
3. **Navigate to COREDIRECTIVE_ENGINE**
4. **Create .env** from template (populate secrets)
5. **Deploy Docker stack** via `docker compose up -d`
6. **Access n8n** at the output URL
7. **Setup Cloudflare Tunnel** for zero-trust access
8. **Configure Operation Nuclear** workflows

---

## Emergency Access (If SSH Key Lost)

AWS Instance Connect provides browser-based terminal access:

1. Open AWS Console → EC2 → Instances
2. Select "cd-alpha-engine" instance
3. Click "Connect" → EC2 Instance Connect tab
4. Opens browser terminal (no SSH key needed)
5. Username: `ec2-user`

---

## Updating Infrastructure

**If your IP changes:**
```bash
terraform apply -var="my_ip=$(curl -s http://checkip.amazonaws.com)" --auto-approve
```

**If you need to destroy everything:**
```bash
terraform destroy -var="my_ip=$(curl -s http://checkip.amazonaws.com)" --auto-approve
```

**WARNING:** `destroy` deletes the EC2 instance and all Docker containers. PostgreSQL data is LOST.

---

## Key Files for Reference

- **TERRAFORM_DEPLOYMENT_GUIDE.md** — Complete deployment walkthrough
- **RHEL_System_Init.md** — Phase 2+ for Docker stack deployment
- **Technical_Vault.md** — Architecture deep-dive
- **ADHD_Runbook.md** — Operational procedures

---

**Version:** 1.0.0-ALPHA  
**Date:** January 30, 2026  
**Status:** ✅ Ready for deployment  
**Next:** Follow TERRAFORM_DEPLOYMENT_GUIDE.md
