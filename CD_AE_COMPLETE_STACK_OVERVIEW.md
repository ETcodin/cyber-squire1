# CoreDirective Alpha-Engine (CD-AE): Complete Stack Overview

**Version:** 1.0.0-ALPHA  
**Status:** 🟢 PRODUCTION-READY  
**Date:** January 30, 2026  
**Operation:** Nuclear (C-suite cybersecurity outreach campaign, Jan-Mar 2026)  
**Goal:** $120k-$170k role targeting

---

## EXECUTIVE SUMMARY

The CoreDirective Alpha-Engine is a **three-tier, locally-hosted automation platform** designed to scale C-suite outreach campaigns while maintaining complete privacy and cost efficiency.

### The Three Pillars

| Pillar | Component | Technology | Memory Cap | Purpose |
|--------|-----------|-----------|-----------|---------|
| **Brain** | Inference Engine | Ollama + Qwen 3 8B (4-bit) | 7.5GB | Generate personalized outreach emails via local AI |
| **Orchestrator** | Workflow Engine | n8n automation platform | 2GB | Trigger workflows: Notion → AI → Gmail → Slack |
| **Memory** | Database Layer | PostgreSQL 16 (Alpine) | 4GB | Store leads, email drafts, response tracking |

### The Hard Shell (Infrastructure)

| Layer | Component | AWS Service | Specification | Purpose |
|-------|-----------|----------|---------------|---------|
| Compute | EC2 Instance | t3.xlarge | 4 vCPU, 16GB RAM, 100GB gp3 SSD | Host all three pillars |
| Security | Security Group | AWS Security Groups | Zero-trust (IP-restricted SSH/n8n) | Perimeter defense |
| Networking | Public IP | Elastic IP | Auto-assigned | Access point for n8n/SSH |
| Remote Access | Tunnel | Cloudflare Tunnel | Zero-trust proxy | Replace public IP exposure (post-deployment) |

---

## ARCHITECTURE DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│                    OPERATION NUCLEAR WORKFLOW                    │
│  Notion DB → AI Agent → Slack Approval → Gmail Send → Tracking  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│              COREDIRECTIVE ALPHA-ENGINE (n8n)                    │
│  Orchestrator: Workflow triggers, data transformation, logging   │
└──────────┬──────────────────┬──────────────────┬────────────────┘
           │                  │                  │
    ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐
    │ BRAIN       │    │ ORCHESTRATOR│    │ MEMORY      │
    │ (Ollama)    │    │ (n8n)       │    │ (PostgreSQL)│
    │             │    │             │    │             │
    │ Qwen 3 8B   │    │ Workflow    │    │ Lead DB     │
    │ 7.5GB cap   │    │ logic       │    │ 4GB cap     │
    │             │    │ 2GB cap     │    │             │
    │ Port: 11434 │    │ Port: 5678  │    │ Port: 5432  │
    └─────────────┘    └─────────────┘    └─────────────┘
           │                  │                   │
           └──────────────────┼───────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  DOCKER BRIDGE    │
                    │  NETWORK          │
                    │  172.25.0.0/16    │
                    └─────────┬─────────┘
                              │
┌─────────────────────────────┼─────────────────────────────────────┐
│          AWS EC2 t3.xlarge (Amazon Linux 2023 / RHEL 9.x)         │
│                   IP: 54.xxx.xxx.xxx (Elastic IP)                 │
│                                                                    │
│  Storage: 100GB gp3 SSD (3000 IOPS, 125 MB/s throughput)          │
│  RAM: 16GB total (4GB PostgreSQL + 2GB n8n + 7.5GB Ollama + 2.5GB OS) │
│                                                                    │
│  Security Group (Zero-Trust):                                     │
│  - SSH (22):     Your IP + AWS Instance Connect CIDR              │
│  - n8n (5678):   Your IP only                                     │
│  - Egress:       All traffic (Docker pulls, API calls)            │
│                                                                    │
│  Google Drive Integration:                                        │
│  - Rclone mount at /data/media/GDRIVE                             │
│  - Persistent systemd daemon                                      │
│  - Automated backup cron jobs                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

## COMPLETE FILE INVENTORY

### 1. TERRAFORM IaC (Infrastructure Provisioning)

**Files:**
- `main.tf` (89 lines) — EC2 + Security Group + Bootstrap
- `variables.tf` (10 lines) — Input variables (my_ip, key_name)
- `outputs.tf` (7 lines) — Output values (public_ip, n8n_url)

**Deployment Command:**
```bash
terraform apply -var="my_ip=$(curl -s http://checkip.amazonaws.com)" --auto-approve
```

**Time to Deploy:** 2-3 minutes

**Result:** t3.xlarge EC2 instance running Amazon Linux 2023, Docker installed, directory structure created

---

### 2. DOCKER ORCHESTRATION (Application Deployment)

**Files:**
- `COREDIRECTIVE_ENGINE/docker-compose.yaml` — Four-service stack definition
- `COREDIRECTIVE_ENGINE/.env.template` — Secrets template (copy to .env)

**Key Services:**
1. `cd-db` — PostgreSQL 16 Alpine (4GB memory limit)
2. `cd-n8n` — n8n automation engine (2GB memory limit)
3. `cd-ollama` — Ollama + Qwen 3 8B (7.5GB memory limit)
4. `cd-service-moltbot` — Lead enrichment & automation bot (Phase 2 - currently disabled)
5. `tunnel-cyber-squire` — Cloudflare Zero Trust Tunnel (active)

**Deployment Command:**
```bash
docker compose up -d
docker compose ps  # Verify all 4 services "Up (healthy)"
```

**Time to Deploy:** 5-10 minutes (Qwen 3 model already cached from bootstrap)

**Result:** All three pillars running with PostgreSQL healthy checks, n8n accessible at port 5678

---

### 3. SYSTEM INITIALIZATION (Post-EC2 Setup)

**Files:**
- `docs/RHEL_System_Init.md` — Step-by-step bootstrap (5 phases)

**Phases:**
1. System prep (dnf, Docker, Docker Compose V2)
2. CD-AE deployment (docker-compose.yaml, .env setup)
3. n8n access (browser login)
4. Cloudflare Tunnel (zero-trust remote access)
5. Operation Nuclear (Notion trigger + first batch)

**Time to Complete:** 30-45 minutes (manual)

---

### 4. OPERATIONAL DOCUMENTATION

**Files:**
- `docs/Employment_Proof.md` — Executive summary (15 pages)
  - Operation Nuclear timeline, ROI, success criteria
  
- `docs/Technical_Vault.md` — Architecture deep-dive (15+ pages)
  - AWS instance optimization, PostgreSQL tuning, Ollama memory profiling
  - Alert thresholds, disaster recovery procedures
  
- `docs/ADHD_Runbook.md` — Operational playbook (jargon-free, copy-paste commands)
  - Daily health checks, common problems + fixes
  - Backup/restore procedures, Cloudflare setup
  
- `docs/Rclone_Google_Drive_Setup.md` — Content automation (15+ pages)
  - Rclone installation + configuration for RHEL
  - Google Drive mounting via systemd service
  - n8n integration examples (watch directory, process videos)
  - Automation recipes (daily backup cron jobs)

---

### 5. DEPLOYMENT GUIDES

**Files:**
- `TERRAFORM_QUICKREF.md` — One-page deployment checklist
- `docs/TERRAFORM_DEPLOYMENT_GUIDE.md` — Complete Terraform walkthrough (15+ pages)
  - Prerequisites, step-by-step workflow, troubleshooting matrix
  - Cost estimation, state management, advanced S3 backend setup

---

### 6. AI AGENT CODING INSTRUCTIONS

**Files:**
- `.github/copilot-instructions.md` — GitHub Copilot agent guidance
  - Project overview, naming conventions, common modification scenarios
  - Essential Docker/database workflows, security patterns

---

## DEPLOYMENT SEQUENCE (Complete Timeline)

### Step 1: Local Prep (5 minutes)

```bash
# 1. Get your public IP
curl -s http://checkip.amazonaws.com

# 2. Ensure AWS credentials configured
aws configure

# 3. Ensure EC2 key pair exists (cyber-squire-key)
aws ec2 describe-key-pairs --key-names cyber-squire-key
```

### Step 2: Terraform Infrastructure (2-3 minutes)

```bash
cd /Users/et/cyber-squire-ops
terraform init
terraform validate
terraform plan -var="my_ip=<YOUR_IP>"
terraform apply -var="my_ip=<YOUR_IP>" --auto-approve
# Output: engine_public_ip = "54.xxx.xxx.xxx"
```

### Step 3: EC2 Bootstrap Wait (5 minutes)

```bash
# SSH into instance
ssh -i cyber-squire-key.pem ec2-user@54.xxx.xxx.xxx

# Monitor bootstrap progress
tail -f /var/log/cloud-init-output.log
# Wait for "Complete!" message
```

### Step 4: Docker Stack Deployment (10 minutes)

```bash
# Follow RHEL_System_Init.md Phase 2
cd /home/ec2-user/COREDIRECTIVE_ENGINE
cp .env.template .env
nano .env  # Populate with secrets

# Upload docker-compose.yaml (from local machine)
scp docker-compose.yaml ec2-user@54.xxx.xxx.xxx:/home/ec2-user/COREDIRECTIVE_ENGINE/

# Deploy
docker compose up -d
docker compose ps
```

### Step 5: Verify & Configure (20 minutes)

```bash
# Check all containers healthy
docker compose ps

# Access n8n
open http://54.xxx.xxx.xxx:5678

# Configure first Operation Nuclear workflow
# (Notion trigger → Qwen 3 AI Agent → Gmail send)
```

### Total Time to Full Production: ~45 minutes

---

## COST BREAKDOWN

**AWS Monthly Costs:**

| Service | Cost | Notes |
|---------|------|-------|
| EC2 t3.xlarge on-demand | $122 | 730 hours/month, us-east-1 |
| EBS gp3 100GB | $8 | 3000 IOPS, 125 MB/s |
| Data transfer (egress) | $5-15 | Depends on Google Drive sync volume |
| **Total Monthly** | **$135-150** | ✅ Well under $120k/year budget |

**Cost Optimizations (if needed):**
- Use t3.medium instead: $40/month (but may be too slow)
- Use Spot Instances: Save 70% ($36/month instead of $122)
- Enable auto-stopping if not 24/7

**Free/Included:**
- Docker images (already cached on instance)
- n8n platform (open-source)
- PostgreSQL 16 (open-source)
- Ollama + Qwen 3 (open-source)
- Rclone (open-source)
- Google Drive integration (free tier: 15GB, paid: 100GB+)

---

## NAMING CONVENTIONS (The "Naming Game")

All project components follow **CoreDirective Standard** for ADHD-friendly discovery:

```
AWS Resources:        cd-*
                      └─ cd-alpha-engine (EC2 instance)
                      └─ cd-engine-sg (Security Group)

Docker Services:      cd-*
                      └─ cd-service-db (PostgreSQL)
                      └─ cd-service-n8n (n8n orchestrator)
                      └─ cd-service-ollama (Ollama + Qwen 3)
                      └─ cd-service-moltbot (lead automation - Phase 2)
                      └─ tunnel-cyber-squire (Cloudflare Tunnel - active)

Docker Network:       cd-net

Docker Volumes:       cd-*-data
                      └─ cd-postgres-data
                      └─ cd-n8n-data
                      └─ cd-ollama-data

Environment Vars:     CD_*
                      └─ CD_DB_USER
                      └─ CD_DB_PASS
                      └─ CD_N8N_KEY
                      └─ CD_OLLAMA_MODEL

Directories:          COREDIRECTIVE_ENGINE/
                      └─ CD_MEDIA_VAULT/
                      └─ CD_BACKUPS/
```

**Why:** Instant searchability. No ambiguity. Perfect for container/resource discovery.

---

## SECURITY MODEL (Three Layers)

### Layer 1: AWS Security Group (Terraform-managed)

**Ingress Rules:**
- SSH (22): Restricted to `<your_ip>/32` + AWS Instance Connect CIDR `18.206.107.24/29`
- n8n (5678): Restricted to `<your_ip>/32`
- All other ports: DENIED

**Egress Rules:**
- All traffic (0.0.0.0/0): ALLOWED (for Docker pulls, API calls)

**Benefit:** If you lose SSH key, use AWS Instance Connect (browser terminal)

### Layer 2: Cloudflare Tunnel (Application Layer - Post-Deployment)

```bash
# After docker compose up -d
cloudflared tunnel create cd-alpha-tunnel
cloudflared tunnel route dns cd-alpha-tunnel yourdomain.com
cloudflared tunnel run cd-alpha-tunnel
```

**Benefit:** No direct public IP exposure. Zero-trust authentication.

### Layer 3: Database Credentials (Data Layer)

- PostgreSQL password: `.env` (git-ignored, 32-char random)
- n8n encryption key: `.env` (32-char random, for sensitive credentials)
- Ollama API: Internal-only (no public port exposure)

**Benefit:** Credentials never appear in source code. Rotated quarterly.

---

## INTEGRATION POINTS (External APIs)

| Integration | Status | Purpose | Notes |
|-------------|--------|---------|-------|
| Notion API | Post-deployment | Lead database trigger | Fetch contacts from Operation Nuclear table |
| Gmail API | Post-deployment | Email delivery | Send personalized outreach emails |
| Slack Webhook | Post-deployment | Human approval gate | Notify before sending live emails |
| Google Drive | Rclone mount | Content storage & backup | 2TB for media + PostgreSQL dumps |
| Cloudflare Tunnel | Post-deployment | Remote access | Replace public IP with zero-trust proxy |

**Flow Example:**
```
Notion (Lead DB)
    ↓
n8n (Workflow Trigger)
    ↓
Qwen 3 8B (AI Agent)
    ├─ Generate personalized email
    └─ Draft subject line
    ↓
Slack (Human Gate)
    ├─ Send draft for review
    └─ Wait for approval
    ↓
Gmail API (Send)
    ├─ Send approved email
    └─ Log to PostgreSQL
    ↓
PostgreSQL (Audit Trail)
    ├─ Track send status
    └─ Store response metadata
    ↓
Google Drive (Backup)
    └─ Daily backup via cron job
```

---

## PERFORMANCE TARGETS

**Application-Level SLAs:**

| Metric | Target | Notes |
|--------|--------|-------|
| n8n workflow latency | <5 sec | Notion → AI → Slack (end-to-end) |
| Ollama inference time | 1-2 sec | Per 200-token prompt |
| PostgreSQL query response | <100ms | For lead lookups, tracking queries |
| Email send rate | 10-20/hr | Respectful rate-limiting (avoid Gmail blocks) |
| Memory headroom | >2GB free | System buffer (never under 2GB) |

**Infrastructure SLAs:**

| Metric | Threshold | Action |
|--------|-----------|--------|
| CPU usage | >80% | Monitor for sustained load |
| Memory usage | >14GB | Restart offending container |
| Ollama VRAM | >7.5GB | Restart Ollama container |
| PostgreSQL conn | >180/200 | Check for leaked connections |
| Disk usage | >90GB | Clean old backups, Ollama cache |

---

## MONITORING & OBSERVABILITY

**Daily Health Checks (via ADHD_Runbook.md):**

```bash
# Check container status
docker compose ps

# Check memory usage
docker stats --no-stream

# Check PostgreSQL connectivity
docker exec cd-db psql -U cd_admin -d cd_automation_db -c "SELECT 1"

# Check Ollama inference
curl http://localhost:11434/api/tags

# Check n8n health
curl http://localhost:5678/healthz
```

**Weekly Maintenance:**
- Review n8n error logs
- Check PostgreSQL connection count
- Verify Rclone backup ran successfully
- Monitor Google Drive storage usage

**Monthly:**
- Rotate credentials in .env (CD_DB_PASS, CD_N8N_KEY)
- Backup terraform.tfstate to secure location
- Review AWS CloudWatch metrics
- Document any manual changes

---

## DISASTER RECOVERY

**If Entire Stack Fails:**

```bash
# 1. SSH into instance
ssh -i cyber-squire-key.pem ec2-user@<IP>

# 2. Check what's broken
docker compose ps

# 3. Restart stack
docker compose down
docker compose up -d

# 4. Restore PostgreSQL from backup
docker exec cd-db pg_restore -U cd_admin -d cd_automation_db -v /backups/backup_YYYYMMDD.dump

# 5. Verify all containers healthy
docker compose ps
```

**If Instance Fails:**

```bash
# 1. Destroy old infrastructure
terraform destroy --auto-approve

# 2. Re-deploy
terraform apply -var="my_ip=$(curl -s http://checkip.amazonaws.com)" --auto-approve

# 3. Re-deploy Docker stack
# (Follow Phase 2 of RHEL_System_Init.md)

# 4. Restore PostgreSQL from Google Drive backup
# (Rclone will have daily dumps in /data/media/GDRIVE/backups/)
```

**Recovery Time Objective (RTO):** 15 minutes  
**Recovery Point Objective (RPO):** 24 hours (daily backups)

---

## NEXT STEPS

1. **Read:** TERRAFORM_DEPLOYMENT_GUIDE.md
2. **Prepare:** Get your public IP + AWS credentials ready
3. **Deploy:** Run `terraform apply`
4. **Wait:** Bootstrap completes (5 min)
5. **Configure:** Follow RHEL_System_Init.md Phase 2-5
6. **Launch:** Create first Operation Nuclear workflow
7. **Monitor:** Daily health checks via ADHD_Runbook.md

---

## SUPPORT & DOCUMENTATION

**For Questions About:**
- **Infrastructure (Terraform, EC2)** → TERRAFORM_DEPLOYMENT_GUIDE.md
- **Docker orchestration** → docker-compose.yaml comments
- **Daily operations** → ADHD_Runbook.md
- **Deep technical details** → Technical_Vault.md
- **Business case/ROI** → Employment_Proof.md
- **Google Drive integration** → Rclone_Google_Drive_Setup.md
- **AI agent development** → .github/copilot-instructions.md

---

**CoreDirective Alpha-Engine v1.0.0  
Deployed for Operation Nuclear  
January 30, 2026  
Status: ✅ PRODUCTION-READY**
