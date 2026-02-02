# CoreDirective Automation Engine (CD-AE) - AI Coding Agent Instructions

**Project:** CoreDirective Automation Engine (Operation Nuclear)  
**Version:** 1.0.0  
**Architect:** Emmanuel Tigoue  
**AI Agent Target:** GitHub Copilot, Claude, Cursor, Windsurf  

---

## PROJECT OVERVIEW

The CoreDirective Automation Engine (CD-AE) is a **production-grade, enterprise-hardened automation stack** deployed on AWS EC2 (t3.xlarge) to power "Operation Nuclear"—a direct-outreach campaign targeting C-suite cybersecurity decision-makers.

### The Three Pillars

1. **Brain (Ollama + Qwen 3 8B):** Local AI inference engine for generating personalized outreach emails
2. **Orchestrator (n8n):** Central command center coordinating Notion → Qwen 3 → Gmail workflows
3. **Memory (PostgreSQL 16):** Persistent database replacing SQLite for concurrent workflow execution

### Strategic Mandate

- **Cost:** $0 AI inference (local Qwen 3 vs. $400/month GPU)
- **Privacy:** 100% on-premise reasoning (sensitive outreach never leaves network)
- **Timeline:** 3-month campaign (Jan-Mar 2026) to secure $120k-$170k cybersecurity role
- **Scale:** 500+ C-suite contacts, 10% response rate target

---

## CRITICAL NAMING CONVENTIONS

All project components follow the **CoreDirective Standard** to ensure ADHD-friendly file discovery:

```
Root Directory:     /home/ec2-user/COREDIRECTIVE_ENGINE
Container Prefixes: cd-service-*           (e.g., cd-service-db, cd-service-n8n)
Network Name:       cd-automation-net
Volume Prefixes:    cd-vol-*               (e.g., cd-vol-postgres, cd-vol-ollama)
Environment Vars:   CD_*                   (e.g., CD_DB_PASS, CD_N8N_KEY)
```

**Why This Matters:** When troubleshooting, all project-related containers/networks are instantly identifiable. No ambiguity.

---

## ESSENTIAL WORKFLOWS

### Infrastructure Commands

```bash
# Verify all containers are healthy
docker-compose ps

# View real-time logs (last 50 lines, follow mode)
docker-compose logs -f --tail=50

# Restart entire stack
docker-compose down && sleep 10 && docker-compose up -d

# Check resource usage (memory, CPU)
docker stats --no-stream

# Access PostgreSQL directly
docker exec -it cd-service-db psql -U cd_admin -d cd_automation_db

# Run Ollama model manually
docker exec -it cd-service-ollama ollama run qwen3:8b-instruct-q4_K_M
```

### Database Maintenance

```bash
# Create manual backup
docker exec cd-service-db pg_dump -U cd_admin -d cd_automation_db -Fc \
  > /home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS/backup_$(date +%Y%m%d).dump

# List all backups
ls -lh /home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS/

# Restore from backup
docker-compose stop cd-service-n8n
docker exec cd-service-db pg_restore -U cd_admin -d cd_automation_db -v /backups/backup_YYYYMMDD.dump
docker-compose up -d
```

### n8n Workflow Development

```bash
# SSH into EC2
ssh -i cyber-squire-key.pem ubuntu@<elastic-ip>

# Navigate to project
cd /home/ec2-user/COREDIRECTIVE_ENGINE

# Access n8n at http://<ip>:5678
# Login: admin@yourdomain.com / ${CD_N8N_PASS}

# Create workflow:
# 1. Notion Trigger (Operation Nuclear table)
# 2. AI Agent Node (call Qwen 3 at http://cd-service-ollama:11434)
# 3. Human approval (Slack webhook)
# 4. Gmail send (on approval)
# 5. Notion update (mark as "Sent")
```

### Ollama Integration

```bash
# Download Qwen 3 model (one-time)
docker exec -it cd-service-ollama ollama pull qwen3:8b-instruct-q4_K_M

# List available models
docker exec cd-service-ollama ollama list

# API endpoint for n8n AI Agent nodes
# POST http://cd-service-ollama:11434/api/generate
# or
# POST http://cd-service-ollama:11434/api/chat
```

---

## CODEBASE PATTERNS & CONVENTIONS

### Environment Variable Management

**Pattern:** All secrets stored in `.env` (git-ignored)

```env
# Database credentials
CD_DB_USER=cd_admin
CD_DB_PASS=<32-char random string>
CD_DB_NAME=cd_automation_db

# n8n encryption
CD_N8N_KEY=<32-char random string>
CD_N8N_JWT=<32-char random string>

# Ollama/Qwen 3
CD_OLLAMA_HOST=cd-service-ollama
CD_OLLAMA_PORT=11434
CD_OLLAMA_MODEL=qwen3:8b-instruct-q4_K_M
```

**Do NOT:**
- Hardcode passwords in docker-compose.yaml
- Commit .env to git
- Share .env via email/Slack

### Docker Compose Structure

**Pattern:** Single `docker-compose.yaml` manages all services with explicit healthchecks

```yaml
services:
  cd-service-db:          # PostgreSQL 16
  cd-service-n8n:         # n8n orchestrator
  cd-service-ollama:      # Ollama + Qwen 3
  cd-service-moltbot:     # Lead enrichment & automation bot (currently disabled)

networks:
  cd-automation-net:      # Bridge network for inter-container communication

volumes:
  cd-vol-postgres         # Database persistence
  cd-vol-n8n              # n8n workflows & config
  cd-vol-ollama           # Qwen 3 model cache
```

**Key Pattern:** All containers communicate via internal Docker network (172.28.0.0/16). No direct port exposure to public internet except:
- Port 5678 (n8n) → via Cloudflare Tunnel only
- Port 22 (SSH) → restricted to authorized IP

### n8n AI Agent Nodes

**Pattern:** All AI reasoning uses local Ollama API (no external API calls)

```json
{
  "node_type": "AI Agent",
  "api_endpoint": "http://cd-service-ollama:11434/api/chat",
  "model": "qwen3:8b-instruct-q4_K_M",
  "system_prompt": "You are a, a CASP+ certified architect known for brutally honest, direct communication.",
  "temperature": 0.7,
  "max_tokens": 200,
  "timeout_ms": 30000
}
```

### PostgreSQL Optimization

**Pattern:** Tuned for 16GB t3.xlarge instance with concurrent workflow execution

```sql
shared_buffers = 4GB
effective_cache_size = 8GB
work_mem = 64MB
max_connections = 200
random_page_cost = 1.1         -- SSD optimization
jit = on                       -- Just-in-time compilation
```

---

## SECURITY & COMPLIANCE PATTERNS

### Network Isolation

**Pattern:** Zero-trust architecture with explicit security group rules

- SSH (Port 22): Restricted to `<your-ip>/32` only
- HTTP/HTTPS (Ports 80/443): Open for Cloudflare Tunnel ingress only
- All internal ports (5432, 5678, 11434): Restricted to `172.28.0.0/16` (Docker bridge)

### Encryption & Secrets

**Pattern:** All credentials rotated every 90 days

```
Rotation Schedule:
- CD_DB_PASS: Quarter-end (Mar 31, Jun 30, Sep 30, Dec 31)
- CD_N8N_KEY: Mid-quarter
- CD_N8N_JWT: Mid-quarter

Procedure:
1. Generate new value: openssl rand -base64 32
2. Update .env file
3. Restart affected container: docker-compose restart <service>
4. Verify logs for successful connection
5. Document in audit trail (docs/ADHD_Runbook.md)
```

### Audit & Compliance

**Pattern:** Three-tier documentation for accountability

- `docs/Employment_Proof.md` — Executive summary (business case, ROI, timeline)
- `docs/Technical_Vault.md` — Deep-dive (architecture, configs, endpoints)
- `docs/ADHD_Runbook.md` — Operational playbook (step-by-step recovery, no jargon)

---

## FILE STRUCTURE & KEY LOCATIONS

```
/home/ec2-user/COREDIRECTIVE_ENGINE/
├── docker-compose.yaml              ← All service definitions
├── .env.template                    ← Secrets template (NEVER commit .env)
├── .env                             ← Active secrets (git-ignored)
│
├── CD_VOL_POSTGRES/                 ← PostgreSQL data
├── CD_VOL_N8N/                      ← n8n workflows & credentials
├── CD_VOL_OLLAMA/                   ← Qwen 3 model cache (~4.7GB)
├── CD_MEDIA_VAULT/                  ← Central storage for workflows
├── CD_BACKUPS/                      ← Daily database backups
│
├── docs/
│   ├── Employment_Proof.md           ← Executive summary
│   ├── Technical_Vault.md            ← Architecture deep-dive
│   └── ADHD_Runbook.md               ← Operational guide (no jargon)
│
└── .github/
    └── copilot-instructions.md       ← This file
```

---

## COMMON MODIFICATION SCENARIOS

### Adding a New Workflow Integration

**Pattern:** Always use n8n's UI first; commit workflow JSON to version control

1. Create workflow in n8n UI
2. Export as JSON: Workflow → Export
3. Commit to git: `git add workflows/<name>.json`
4. Document in n8n: Add description explaining trigger, logic, output

### Scaling to Higher Load

**Pattern:** Monitor resource usage; horizontal scaling not supported (single-instance)

```bash
# If Ollama memory usage > 6.5GB
docker-compose restart cd-service-ollama

# If PostgreSQL connections > 180/200
Check for leaked connections: docker exec cd-service-db \
  psql -U cd_admin -c "SELECT * FROM pg_stat_activity"
```

### Updating Ollama Model Version

**Pattern:** Pull new version; stop n8n; switch model name; restart

```bash
# Pull new Qwen version
docker exec -it cd-service-ollama ollama pull qwen3:8b-instruct-q4_K_M

# Update .env
sed -i 's/CD_OLLAMA_MODEL=.*/CD_OLLAMA_MODEL=qwen3:8b-instruct-q4_K_M/' .env

# Restart
docker-compose restart cd-service-ollama cd-service-n8n
```

---

## INTEGRATION POINTS & EXTERNAL DEPENDENCIES

| Integration | Status | Endpoint | Purpose |
|-------------|--------|----------|---------|
| Notion API | Post-deployment | https://api.notion.com | Lead database trigger |
| Gmail API | Post-deployment | gmail.googleapis.com | Email delivery |
| Slack Webhook | Post-deployment | hooks.slack.com | Human approval notifications |
| Cloudflare Tunnel | Post-deployment | cfargotunnels.com | Remote access (no port exposure) |

**Key Pattern:** All external API calls go through n8n (not direct from Ollama). This centralizes logging and audit trails.

---

## TROUBLESHOOTING QUICK REFERENCE

| Issue | Diagnosis Command | Fix |
|-------|-------------------|-----|
| Container won't start | `docker-compose logs -f cd-service-<name>` | Check error message; restart: `docker-compose restart cd-service-<name>` |
| Ollama OOM | `docker stats \| grep ollama` | If >6.5GB: `docker-compose restart cd-service-ollama` |
| n8n database connection | n8n UI → Settings → About | Verify `CD_DB_PASS` in .env matches active password |
| Disk full | `du -sh /home/ec2-user/COREDIRECTIVE_ENGINE/*` | Delete old backups; clean Ollama cache |
| Can't SSH | `ssh -i key.pem ubuntu@<ip>` | Verify IP correct; check SSH security group rule |

---

## PERFORMANCE TARGETS

- **n8n workflow latency:** <5 seconds end-to-end (Notion → Qwen → Slack)
- **Ollama inference time:** 1-2 seconds per 200-token prompt
- **PostgreSQL query response:** <100ms for workflow queries
- **Memory headroom:** Minimum 2GB free at all times

---

## DEPLOYMENT CHECKLIST (Pre-Production)

- [ ] t3.xlarge instance created (4vCPU, 16GB RAM, 100GB gp3 SSD)
- [ ] Ubuntu 24.04 LTS OS installed
- [ ] Docker & docker-compose installed
- [ ] .env file created with secure passwords (via `openssl rand -base64 32`)
- [ ] docker-compose.yaml validated: `docker-compose config`
- [ ] All containers healthy: `docker-compose ps` shows "Up (healthy)"
- [ ] Qwen 3 model downloaded (~4.7GB)
- [ ] PostgreSQL restored from backup or initialized fresh
- [ ] n8n accessible: `curl http://localhost:5678`
- [ ] Ollama API responsive: `curl http://localhost:11434/api/tags`
- [ ] First Operation Nuclear workflow created and tested
- [ ] Cloudflare Tunnel configured (optional)
- [ ] Backup verified: `docker exec cd-service-db pg_dump ... | head`

---

## NEXT STEPS FOR AI AGENTS

When tasked with modifying this codebase:

1. **Always check naming conventions** — Use `cd-*` prefixes for any new components
2. **Read all three documentation files first** — Employment_Proof explains "why", Technical_Vault explains "how", ADHD_Runbook explains "what buttons to press"
3. **Test locally before deploying** — Use `docker-compose up -d` to test changes
4. **Maintain audit trail** — Update docs after any infrastructure change
5. **Never commit .env** — Add to .gitignore if not already present
6. **Monitor resource usage** — Ollama can consume all available RAM if not managed

---

**Version:** 1.0.0  
**Last Updated:** January 29, 2026  
**Next Review:** April 29, 2026  
**Maintained By:** Emmanuel Tigoue
