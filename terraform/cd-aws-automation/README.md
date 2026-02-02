# CD-AWS-AUTOMATION Deployment Guide

## Overview

**CD-AWS-AUTOMATION** is a production-grade Terraform infrastructure for deploying the CoreDirective Automation Engine with:

- **Custom VPC** with public/private subnet isolation
- **Self-managed NAT instance** replacing AWS NAT Gateway ($28/mo savings)
- **S3 + KMS backend** for secure, shared Terraform state
- **CD-Standard naming** for consistent resource management
- **Zero-trust security** with minimal attack surface

**Monthly Cost**: ~$142 (includes NAT savings)
**Deployment Time**: ~15 minutes
**Best For**: Production campaigns, team deployments, compliance requirements

For quick demos and testing, see [../simple-ec2/README.md](../simple-ec2/README.md).

---

## Architecture

```
Internet
   ↓
Internet Gateway (cd-net-igw-01)
   ↓
┌─────────────────────────────────────────────────────┐
│ VPC: cd-net-vpc-01 (10.0.0.0/16)                   │
│                                                      │
│  ┌─────────────────────────────────────────┐       │
│  │ Public Subnet: cd-net-pub-01            │       │
│  │ (10.0.10.0/24)                          │       │
│  │                                          │       │
│  │  ┌──────────────────────────────┐       │       │
│  │  │ NAT Instance                 │       │       │
│  │  │ cd-srv-nat-01 (t3.nano)      │       │       │
│  │  │ $3.80/mo vs $32.85 NAT GW    │       │       │
│  │  └──────────────────────────────┘       │       │
│  └─────────────────────────────────────────┘       │
│                     ↓                                │
│  ┌─────────────────────────────────────────┐       │
│  │ Private Subnet: cd-net-prv-01           │       │
│  │ (10.0.20.0/24)                          │       │
│  │                                          │       │
│  │  ┌──────────────────────────────┐       │       │
│  │  │ COREDIRECTIVE_ENGINE         │       │       │
│  │  │ cd-srv-cdae-01 (t3.xlarge)   │       │       │
│  │  │ ├─ PostgreSQL 16              │       │       │
│  │  │ ├─ n8n (Cloudflare Tunnel)    │       │       │
│  │  │ └─ Ollama + Qwen 3 8B         │       │       │
│  │  └──────────────────────────────┘       │       │
│  └─────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘

Terraform State:
  S3 Bucket: cd-str-tfstate-01 (versioned, KMS encrypted)
  KMS Key: cd-iam-kms-tfstate
```

---

## Prerequisites

### 1. AWS Account Setup

- AWS Account with permissions to create: VPC, EC2, S3, KMS, IAM
- AWS CLI configured: `aws configure`
- AWS credentials in `~/.aws/credentials`

### 2. Tools

- **Terraform** 1.10+ ([install](https://www.terraform.io/downloads))
- **AWS CLI** 2.x ([install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **SSH client** for instance access

### 3. EC2 Key Pair

Create SSH key pair in us-east-1:

```bash
aws ec2 create-key-pair \
  --key-name cyber-squire-ops \
  --query 'KeyMaterial' \
  --output text > ~/cyber-squire-ops.pem

chmod 400 ~/cyber-squire-ops.pem
```

### 4. S3 Backend Setup (Optional but Recommended)

**Benefits**: Shared state for team collaboration, state locking, encryption at rest

**Steps**:

1. Create KMS key:
```bash
aws kms create-key \
  --description "Terraform state encryption for CD-AWS-AUTOMATION" \
  --key-usage ENCRYPT_DECRYPT \
  --origin AWS_KMS \
  --tags TagKey=Name,TagValue=cd-iam-kms-tfstate

# Save the KeyId from output
# Example: arn:aws:kms:us-east-1:123456789012:key/abcd1234-...

# Create alias
aws kms create-alias \
  --alias-name alias/cd-iam-kms-tfstate \
  --target-key-id [YOUR_KEY_ID]
```

2. Create S3 bucket:
```bash
aws s3api create-bucket \
  --bucket cd-str-tfstate-01-YOUR_ACCOUNT_ID \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket cd-str-tfstate-01-YOUR_ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket cd-str-tfstate-01-YOUR_ACCOUNT_ID \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "alias/cd-iam-kms-tfstate"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket cd-str-tfstate-01-YOUR_ACCOUNT_ID \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

3. Configure backend:
```bash
cp backend.tf.example backend.tf
nano backend.tf
# Replace REPLACE_WITH_BUCKET_NAME with your bucket name
# Replace REPLACE_WITH_REAL_KMS_KEY_ARN with your KMS key ARN
```

**Skip S3 backend?** Delete `backend.tf.example`. Terraform will use local state. Not recommended for team collaboration.

---

## Quick Start (6 Steps)

### Step 1: Clone Repository

```bash
git clone <your-repo-url>
cd cyber-squire-ops/terraform/cd-aws-automation
```

### Step 2: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Required: Update your public IP
my_ip = "YOUR_PUBLIC_IP/32"

# Optional: Customize instance types, VPC CIDRs, etc.
```

Get your public IP:
```bash
curl checkip.amazonaws.com
```

### Step 3: Initialize Terraform

```bash
terraform init
```

If using S3 backend, Terraform will prompt to migrate state.

### Step 4: Plan Infrastructure

```bash
terraform plan
```

Review the plan. Expected resources:
- 1 VPC (cd-net-vpc-01)
- 2 Subnets (public, private)
- 1 Internet Gateway
- 2 Route Tables
- 2 Security Groups
- 2 EC2 Instances (NAT, CDAE)

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` to confirm.

**Duration**: ~5 minutes

### Step 6: Verify Deployment

```bash
# Get NAT instance public IP
terraform output nat_public_ip

# Get CDAE instance private IP
terraform output cdae_private_ip

# SSH to NAT instance (verify connectivity)
ssh -i ~/cyber-squire-ops.pem ec2-user@$(terraform output -raw nat_public_ip)

# SSH to CDAE instance via NAT jump host
ssh -i ~/cyber-squire-ops.pem -J ec2-user@$(terraform output -raw nat_public_ip) ec2-user@$(terraform output -raw cdae_private_ip)
```

---

## Post-Deployment Setup

### 1. Bootstrap COREDIRECTIVE_ENGINE

SSH to CDAE instance and run bootstrap script:

```bash
# SSH via NAT jump host
NAT_IP=$(terraform output -raw nat_public_ip)
CDAE_IP=$(terraform output -raw cdae_private_ip)

ssh -i ~/cyber-squire-ops.pem -J ec2-user@$NAT_IP ec2-user@$CDAE_IP

# On CDAE instance
cd /home/ec2-user/COREDIRECTIVE_ENGINE

# Clone your repository (or upload config files)
git clone <your-repo> .

# Run bootstrap script
./cdae-init.sh
```

### 2. Configure Secrets

```bash
# Copy environment template
cp .env.template .env

# Edit with your real credentials
nano .env

# Set restrictive permissions
chmod 600 .env
```

### 3. Launch Docker Compose Stack

```bash
docker compose up -d

# Verify all services are running
docker compose ps

# Run health check
./cdae-healthcheck.sh
```

### 4. Test NAT Instance Routing

```bash
# From CDAE instance, test internet access
curl -I https://google.com
# Expected: HTTP 200 (internet access via NAT)

# Verify private IP is used for outbound
curl ifconfig.me
# Expected: NAT instance's public IP
```

### 5. Configure Cloudflare Tunnel

See [../../docs/Technical_Vault.md#cloudflare-tunnel-setup](../../docs/Technical_Vault.md) for Cloudflare Tunnel configuration.

---

## Cost Breakdown

| Resource | Type | Monthly Cost |
|----------|------|--------------|
| CDAE Instance | t3.xlarge | $122 |
| NAT Instance | t3.nano | $3.80 |
| EBS Volume (CDAE) | 100GB gp3 | $8 |
| EBS Volume (NAT) | 8GB gp3 | $0.64 |
| Data Transfer | ~50GB outbound | $5 |
| S3 State Bucket | ~1MB storage | $0.00 |
| KMS Key | Flat rate | $1 |
| **Total** | | **$140.44** |

**Savings vs AWS NAT Gateway**: $28/month ($336/year)

**Cost Optimization Tips**:
- Use Reserved Instances for 1-year commitment: Save 40%
- Reduce CDAE to t3.large for dev environments: Save $61/month
- Use t4g.nano (ARM) for NAT: Save $0.70/month

---

## Configuration

### Files

| File | Purpose |
|------|---------|
| [ec2.tf](./ec2.tf) | CDAE instance, provider config |
| [vpc.tf](./vpc.tf) | VPC, subnets, route tables |
| [nat.tf](./nat.tf) | NAT instance, routing |
| [security-groups.tf](./security-groups.tf) | Security groups |
| [backend.tf.example](./backend.tf.example) | S3 backend template |
| [variables.tf](./variables.tf) | Input variables |
| [outputs.tf](./outputs.tf) | Output values |
| [terraform.tfvars.example](./terraform.tfvars.example) | Variable values template |

### Variables

See [terraform.tfvars.example](./terraform.tfvars.example) for all available variables.

**Required**:
- `my_ip`: Your public IP for SSH access

**Optional** (with defaults):
- `vpc_cidr`: 10.0.0.0/16
- `public_subnet_cidr`: 10.0.10.0/24
- `private_subnet_cidr`: 10.0.20.0/24
- `nat_instance_type`: t3.nano
- `cdae_instance_type`: t3.xlarge
- `cdae_volume_size`: 100 GB
- `key_name`: cyber-squire-ops

---

## Maintenance

### Update Infrastructure

Modify `.tf` files, then:

```bash
terraform plan
terraform apply
```

### Update AMIs

Terraform automatically uses the latest Amazon Linux 2023 AMI. To force an update:

```bash
terraform taint aws_instance.cd_srv_nat_01
terraform taint aws_instance.cd_srv_cdae_01
terraform apply
```

### Backup Terraform State

If using S3 backend, state is automatically versioned. To download a backup:

```bash
terraform state pull > backup-$(date +%Y%m%d).tfstate
```

### Rotate SSH Keys

```bash
# Generate new key pair
aws ec2 create-key-pair \
  --key-name cyber-squire-ops-new \
  --query 'KeyMaterial' \
  --output text > ~/cyber-squire-ops-new.pem

# Update terraform.tfvars
# key_name = "cyber-squire-ops-new"

# Apply changes
terraform apply

# Delete old key pair
aws ec2 delete-key-pair --key-name cyber-squire-ops
```

---

## Troubleshooting

### SSH Connection Refused

**Cause**: Your IP changed (dynamic IP)

**Fix**:
```bash
# Update terraform.tfvars with new IP
my_ip = "$(curl -s checkip.amazonaws.com)/32"

terraform apply
```

### Private Subnet Can't Reach Internet

**Cause**: NAT instance not routing correctly

**Fix**:
```bash
# SSH to NAT instance
ssh -i ~/cyber-squire-ops.pem ec2-user@$(terraform output -raw nat_public_ip)

# Verify source_dest_check is disabled
aws ec2 describe-instance-attribute \
  --instance-id $(terraform output -raw nat_instance_id) \
  --attribute sourceDestCheck
# Expected: "Value": false

# Verify iptables rules
sudo iptables -t nat -L -n -v
# Expected: MASQUERADE rule in POSTROUTING chain

# Restart iptables if needed
sudo systemctl restart iptables
```

### Terraform State Locked

**Cause**: Previous terraform operation interrupted

**Fix**:
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### KMS Key Not Found

**Cause**: backend.tf still has placeholder

**Fix**:
```bash
# Edit backend.tf with real KMS ARN
nano backend.tf

# Re-initialize
terraform init -reconfigure
```

---

## Security

### Current Posture

**Good**:
- SSH restricted to your IP + AWS Instance Connect
- CDAE in private subnet (no direct internet access)
- Security groups follow least-privilege
- EBS volumes encrypted at rest
- Terraform state encrypted with KMS

**To Improve** (for compliance):
- Enable VPC Flow Logs (network traffic monitoring)
- Use AWS Systems Manager Session Manager (eliminate SSH)
- Implement MFA for AWS account
- Enable AWS CloudTrail (audit logging)
- Add WAF in front of Cloudflare Tunnel

### Compliance

Aligned with:
- CIS AWS Foundations Benchmark: Sections 4 (Networking), 5 (Security Groups)
- NIST 800-53: SC-7 (Boundary Protection), AC-4 (Information Flow Enforcement)
- SOC 2 Type II: CC6.1 (Logical Access Controls)

---

## Cleanup

**Destroy all infrastructure** (irreversible):

```bash
terraform destroy
```

**Duration**: ~5 minutes

**What gets deleted**:
- All EC2 instances
- VPC and subnets
- Security groups
- Route tables
- Internet gateway

**NOT deleted** (manual cleanup):
- S3 state bucket (delete manually if desired)
- KMS key (scheduled for deletion, 7-30 day window)
- EC2 key pair
- Cloudflare Tunnel (delete from Cloudflare dashboard)

---

## Next Steps

1. **Review architecture**: [../../docs/CD_AWS_AUTOMATION.md](../../docs/CD_AWS_AUTOMATION.md)
2. **Configure workflows**: [../../COREDIRECTIVE_ENGINE/](../../COREDIRECTIVE_ENGINE/)
3. **Set up monitoring**: [../../docs/Technical_Vault.md#monitoring](../../docs/Technical_Vault.md)
4. **Operational playbook**: [../../docs/ADHD_Runbook.md](../../docs/ADHD_Runbook.md)
5. **Private operations manual**: [../../docs/PRIVATE_OPERATIONS_MANUAL.md](../../docs/PRIVATE_OPERATIONS_MANUAL.md) (local only)

---

## Support

**Issues?**
- [Troubleshooting section](#troubleshooting) above
- [docs/ADHD_Runbook.md](../../docs/ADHD_Runbook.md) - Operational commands
- [docs/Technical_Vault.md](../../docs/Technical_Vault.md) - Deep-dive specs

**Security concerns?**
- Review [../../docs/PRIVATE_OPERATIONS_MANUAL.md](../../docs/PRIVATE_OPERATIONS_MANUAL.md)
- Check AWS Security Groups: `aws ec2 describe-security-groups`
- Audit VPC configuration: `terraform show`

---

## Comparison: Simple EC2 vs CD-AWS-AUTOMATION

| Feature | Simple EC2 | CD-AWS-AUTOMATION |
|---------|-----------|-------------------|
| Deployment Time | 5 min | 15 min |
| Monthly Cost | $135 | $142 |
| VPC | Default VPC | Custom VPC |
| Subnets | Public only | Public + Private |
| NAT | N/A | Self-managed ($28/mo savings) |
| State Backend | Local file | S3 + KMS |
| Naming | Mixed | CD-Standard |
| Security | Basic | Defense-in-depth |
| Team Collaboration | No (local state) | Yes (shared S3 state) |
| Compliance | Minimal | CIS/NIST aligned |
| Best For | Demos, testing | Production, teams |

---

**Last Updated**: 2026-01-30
**Terraform Version**: 1.10+
**AWS Region**: us-east-1
**Deployment**: CD-AWS-AUTOMATION (Production)
