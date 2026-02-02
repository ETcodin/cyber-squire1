# CoreDirective Central Nervous System (CNS)

**Business Automation Engine for Cyber-Squire Operations**

---

## What This Is

Your complete **sovereign business operating system** - a fully automated CNS that runs 24/7 on RHEL 9 with Zero Trust security, eliminating 90% of routine work while tracking your path from $60k debt to $120k-$170k annual revenue.

**Status: Production Ready** ✅

---

## Quick Start (3 Commands)

```bash
cd /path/to/COREDIRECTIVE_ENGINE

# 1. Start infrastructure
docker compose up -d

# 2. Inject credentials
./inject_credentials.sh

# 3. Deploy all workflows
./deploy_workflows.sh
```

**Then:** Complete Google OAuth in n8n GUI (see [QUICKSTART.md](QUICKSTART.md))

---

## What You Get

### 8 Production Workflows

1. **🏥 API Health Monitor** - Tests 6 API credentials every 6 hours
2. **🤖 Moltbot Generator** - Natural language → n8n workflow creation
3. **📂 Drive Watcher** - Monitors 2TB Google Drive for new content
4. **☢️ Operation Nuclear** - Lead enrichment → AI outreach → Auto-send
5. **🎬 YouTube Factory** - Video → Transcript → Metadata → 5 Shorts scripts
6. **💰 Gumroad Solvency** - Sales → 60/30/10 allocation → Debt tracking
7. **📋 Task Manager** - ADHD-optimized productivity system
8. **🧠 AI Router** - Smart routing: Qwen (90%) → Gemini → Claude

### Infrastructure

- **PostgreSQL 16** - Encrypted business data storage
- **n8n** - Workflow orchestration with credential encryption
- **Ollama (Qwen 3)** - Local AI (zero cost)
- **Cloudflare Tunnel** - Zero Trust access gateway

### Security

- ✅ No open ports (Cloudflare Tunnel only)
- ✅ SELinux enforcement with container isolation
- ✅ AES-256 encrypted credentials (via `CD_N8N_KEY`)
- ✅ TLS/HTTPS everywhere
- ✅ Persistent volumes with `:z` SELinux labeling

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Cloudflare Tunnel                        │
│              (n8n.yourdomain.com)                         │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  RHEL 9 AWS Instance                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │          Docker Bridge Network (cd-net)               │  │
│  │                                                       │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │  │
│  │  │   n8n    │◄─┤PostgreSQL│  │ Ollama   │          │  │
│  │  │  :5678   │  │   :5432  │  │ (Qwen 3) │          │  │
│  │  └────┬─────┘  └──────────┘  └──────────┘          │  │
│  │       │                                              │  │
│  │       │ Orchestrates workflows                      │  │
│  │       ▼                                              │  │
│  │  ┌─────────────────────────────────────────┐        │  │
│  │  │  8 Automated Workflows                  │        │  │
│  │  │  • API Health    • Operation Nuclear    │        │  │
│  │  │  • Drive Watcher • YouTube Factory      │        │  │
│  │  │  • Gumroad Track • Task Manager         │        │  │
│  │  │  • Moltbot Gen   • AI Router            │        │  │
│  │  └─────────────────────────────────────────┘        │  │
│  │                                                       │  │
│  │  Volume Mounts (SELinux :z labeled):                │  │
│  │  • CD_VOL_POSTGRES → PostgreSQL data                │  │
│  │  • CD_VOL_N8N → n8n workflows & credentials         │  │
│  │  • CD_VOL_OLLAMA → Qwen models                      │  │
│  │  • /mnt/gdrive → 2TB Google Drive (Rclone FUSE)    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                     ▲
                     │ API Calls
                     │
┌────────────────────┴────────────────────────────────────────┐
│            External Services (via credentials)              │
│  • Anthropic Claude  • Google Workspace  • Perplexity      │
│  • GitHub            • Gumroad           • Notion          │
└─────────────────────────────────────────────────────────────┘
```

---

## Cost Analysis

### Monthly Operating Cost: ~$85

- **AWS RHEL 9 Instance:** $40/month
- **Google Drive 2TB:** $10/month
- **Claude API (strategic):** ~$20/month
- **Gemini API (transcription):** ~$5/month
- **Perplexity API (research):** ~$10/month
- **Qwen/Ollama (local):** $0
- **PostgreSQL (local):** $0
- **Cloudflare Tunnel:** $0

### Break-Even

**Product:** Cyber-Squire OS at $47/sale
**Break-even:** 2 sales/month ($94 revenue > $85 cost)
**Target Revenue:** $120k-$170k/year
**Required Sales:** 7-10 sales/day (2,553-3,617/year)

### ROI Multiplier

Every workflow saves ~2-4 hours/week:
- **8 workflows × 3 hours/week = 24 hours saved/week**
- **24 hours × $50/hour consulting rate = $1,200/week value**
- **$1,200/week × 52 weeks = $62,400/year in saved time**
- **ROI: 61x annual investment**

---

## AI Routing Intelligence

### Cost Optimization via Smart Routing

**90% of requests → Qwen 3 (local, $0)**
- Task analysis
- Email drafts
- File categorization
- Simple metadata generation

**8% of requests → Gemini 2.0 (~$5/month)**
- Video transcription
- Large document analysis (>100k tokens)
- Multi-page PDF processing

**2% of requests → Claude 3.5 (~$20/month)**
- Strategic outreach (Operation Nuclear)
- Complex technical documentation
- Business planning
- Code architecture

### Automatic Routing Logic

```javascript
if (complexity === 'strategic' || priority === 'critical') {
  route = 'claude';  // Premium intelligence
} else if (context_size > 100000 || task.includes('video')) {
  route = 'gemini';  // Large context window
} else {
  route = 'qwen';    // Default, zero cost
}
```

All routing decisions logged to Notion for cost tracking and optimization.

---

## Workflow Details

### 1. API Health Monitor
**Frequency:** Every 6 hours
**Purpose:** Validate all API credentials are active
**On Failure:** Creates Notion alert page
**Tests:** Anthropic, GitHub, Google, Gumroad, Notion, Perplexity

### 2. Moltbot Workflow Generator
**Trigger:** Webhook POST `/webhook/moltbot-command`
**Purpose:** Convert natural language to n8n workflow JSON
**AI Used:** Qwen (simple) or Claude (complex)
**Example:** "Create workflow that posts to Twitter when YouTube video published"

### 3. Google Drive Watcher
**Frequency:** Every 5 minutes
**Purpose:** Monitor `/data/media` for new files
**Actions:** Route videos → YouTube Factory, log all files → Notion
**Supports:** Videos, audio, documents, images

### 4. Operation Nuclear (Lead Enrichment)
**Trigger:** Webhook POST `/webhook/lead-intake`
**Pipeline:**
1. Perplexity researches company (news, tech stack, pain points)
2. Claude drafts hyper-personalized outreach email
3. Saves to Notion with quality score (1-10)
4. Auto-sends if score ≥ 8, flags for manual review if < 8

**Quality Score Factors:**
- Company-specific context usage
- Technical accuracy
- Value proposition clarity
- CTA strength
- Tone appropriateness

### 5. YouTube Content Factory
**Trigger:** Webhook from Drive Watcher (video detected)
**Pipeline:**
1. ffmpeg extracts audio
2. Gemini transcribes (handles up to 2-hour videos)
3. Qwen generates: title, description, 10 tags, 5 Shorts scripts
4. Saves everything to Notion Content Dashboard

**Outputs:**
- SEO-optimized title (< 70 chars)
- 3-paragraph description with keywords
- Full transcript with timestamps
- 5 × 15-30 second Shorts scripts for TikTok/IG/YT

### 6. Gumroad Solvency Engine
**Frequency:** Every hour
**Purpose:** Track sales → Allocate funds → Reduce debt

**60/30/10 Allocation:**
- **60% → Debt Payment** (target: $60k → $0)
- **30% → Reinvestment** (tools, infrastructure, ads)
- **10% → Reserve Fund** (emergency buffer)

**Actions:**
1. Fetch new Gumroad sales
2. Calculate allocation
3. Update Notion debt tracker
4. Log transaction
5. Qwen generates thank you message
6. Gmail sends automated email
7. Celebrate milestones (25%, 50%, 75%, 100%)

### 7. Notion Task Manager (ADHD-Optimized)
**Frequency:** Every 30 minutes
**Purpose:** Reduce executive dysfunction, maximize deep work

**For Active Tasks:**
- Qwen analyzes each task
- Provides realistic time estimates
- Breaks into 3-5 actionable subtasks
- Identifies potential blockers
- Recommends best deep work time window

**For High-Priority Backlog:**
- Claude prioritizes tasks
- Suggests batching strategies
- Identifies automation candidates
- Generates daily schedule respecting energy levels

### 8. AI Intelligence Router
**Trigger:** Webhook POST `/webhook/ai-router`
**Purpose:** Centralized AI gateway for all workflows
**Logs:** Every request to Notion for cost tracking

**Request Format:**
```json
{
  "prompt": "Your task here",
  "context_size": 5000,
  "complexity": "standard|complex|strategic",
  "priority": "standard|high|critical",
  "notion_ai_log_db": "YOUR_DB_ID"
}
```

**Response:**
```json
{
  "response": "AI output",
  "model_used": "qwen|gemini|claude",
  "routing_reason": "Why this model was chosen",
  "timestamp": "2026-01-29T12:00:00Z"
}
```

---

## Files Structure

```
COREDIRECTIVE_ENGINE/
├── docker-compose.yaml          # Service definitions
├── .env.template                # Environment variable template
├── credentials_vault.json       # All API keys (encrypted by n8n)
├── inject_credentials.sh        # One-command credential loading
├── deploy_workflows.sh          # One-command workflow deployment
│
├── workflow_api_healthcheck.json
├── workflow_moltbot_generator.json
├── workflow_gdrive_watcher.json
├── workflow_operation_nuclear.json
├── workflow_youtube_factory.json
├── workflow_gumroad_solvency.json
├── workflow_notion_task_manager.json
├── workflow_ai_router.json
│
├── README.md                    # This file
├── QUICKSTART.md                # 3-step deployment guide
├── CNS_DEPLOYMENT_GUIDE.md      # Full 500+ line technical guide
└── FIX_GOOGLE_OAUTH.md          # OAuth troubleshooting

Volumes (created on first run):
├── CD_VOL_POSTGRES/             # PostgreSQL data
├── CD_VOL_N8N/                  # n8n workflows & credentials
├── CD_VOL_OLLAMA/               # Qwen model storage
└── CD_BACKUPS/                  # Database backups
```

---

## Deployment Checklist

### Prerequisites
- [ ] RHEL 9 AWS instance running
- [ ] Docker & Docker Compose installed
- [ ] Cloudflare Tunnel configured (token in `.env`)
- [ ] Google Drive mounted via Rclone FUSE at `/mnt/gdrive`
- [ ] `.env` file created from `.env.template` with real values

### Phase 1: Infrastructure (5 minutes)
- [ ] Start services: `docker compose up -d`
- [ ] Verify PostgreSQL healthy: `docker exec cd-service-db pg_isready`
- [ ] Verify n8n accessible: `curl https://n8n.yourdomain.com/healthz`
- [ ] Verify Ollama running: `curl http://localhost:11434/api/tags`

### Phase 2: Credentials (2 minutes)
- [ ] Run `./inject_credentials.sh`
- [ ] Verify 6 credentials injected successfully
- [ ] Update Google Cloud Console redirect URI
- [ ] Complete Google OAuth in n8n GUI

### Phase 3: Workflows (5 minutes)
- [ ] Run `./deploy_workflows.sh`
- [ ] Verify 8 workflows deployed successfully
- [ ] Set Notion database IDs in each workflow
- [ ] Activate all workflows (toggle "Active" in n8n)

### Phase 4: Verification (5 minutes)
- [ ] Test AI Router webhook
- [ ] Test Operation Nuclear webhook with dummy lead
- [ ] Upload test video to Google Drive
- [ ] Check n8n executions - all green checkmarks
- [ ] Review Notion databases - data populated correctly

**Total Deployment Time: ~17 minutes**

---

## Post-Deployment Operations

### Daily (30 seconds)
- Check n8n executions tab (green checkmarks)
- Review Notion daily strategy page

### Weekly (10 minutes)
- Review AI Log DB (cost optimization)
- Review Leads DB (conversion rate)
- Review Finance DB (debt progress)
- Review Content DB (video processing success)

### Monthly (1 hour)
- Rotate API keys (see security best practices)
- Export PostgreSQL backup
- Export n8n workflows (git version control)
- Analyze cost vs revenue trends
- Update AI routing logic if needed

---

## Troubleshooting

### Services Won't Start
```bash
# Check logs
docker compose logs cd-service-n8n
docker compose logs cd-service-db

# Restart services
docker compose down
docker compose up -d
```

### Credentials Not Injecting
```bash
# Verify n8n is accessible
curl https://n8n.yourdomain.com/healthz

# Check credentials file syntax
jq . credentials_vault.json

# Re-run injection
./inject_credentials.sh
```

### Google OAuth 400 Error
See [FIX_GOOGLE_OAUTH.md](FIX_GOOGLE_OAUTH.md) for complete resolution guide.

**Quick fix:**
1. Verify `docker-compose.yaml` has `N8N_HOST=https://n8n.yourdomain.com`
2. Update Google Cloud Console redirect URI
3. Restart services: `docker compose down && docker compose up -d`

### Workflows Fail
- Check Notion database IDs are correct
- Verify API credentials are active (run health check workflow)
- Review n8n execution logs for specific errors

---

## Security Best Practices

### Credential Rotation (Every 90 Days)
- Anthropic API key
- GitHub PAT
- Notion API key
- Perplexity API key
- Gumroad API credentials
- n8n API key

### Backup Strategy
```bash
# Daily PostgreSQL backup (automated)
docker exec cd-service-db pg_dump -U ${CD_DB_USER} ${CD_DB_NAME} \
  > ./CD_BACKUPS/backup_$(date +%Y%m%d).sql

# Weekly workflow export
curl -H "X-N8N-API-KEY: ${CD_N8N_KEY}" \
  https://n8n.yourdomain.com/api/v1/workflows > workflows_backup.json
```

### SELinux Audit
```bash
# Check for denials
ausearch -m avc -ts recent

# Adjust container labels if needed
chcon -Rt svirt_sandbox_file_t ./CD_VOL_N8N
```

---

## Roadmap

### Phase 5: Moltbot Mobile Interface (Next)
- WhatsApp Business API integration
- Telegram Bot connection
- Voice command support
- Mobile workflow triggers

### Phase 6: Revenue Optimization
- A/B test product pricing
- Automated upsell sequences
- Affiliate tracking system
- Referral reward automation

### Phase 7: Scale Operations
- Hire VA for manual review queue
- Expand Operation Nuclear to 50 leads/day
- YouTube cadence: 3x/week
- Launch Cyber-Squire community

---

## Support & Documentation

**Quick Start:** [QUICKSTART.md](QUICKSTART.md)
**Full Guide:** [CNS_DEPLOYMENT_GUIDE.md](CNS_DEPLOYMENT_GUIDE.md)
**OAuth Fix:** [FIX_GOOGLE_OAUTH.md](FIX_GOOGLE_OAUTH.md)

**GitHub Issues:** Report bugs or request features
**Notion Knowledge Base:** Internal documentation
**Video Walkthroughs:** Coming to YouTube channel

---

## License & Attribution

**Built for:** Tigou E Theory - Cyber-Squire Operations
**Purpose:** Sovereign business automation with clinical precision
**Philosophy:** Deep work optimization, ADHD accommodation, debt-to-solvency pipeline

**© 2026 Cyber-Squire Operations**

---

**Status: Production Ready** ✅
**Deployment Time: 17 minutes**
**Operating Cost: $85/month**
**Time Saved: 24 hours/week**
**ROI: 61x**

**Your business machine is ready to operate.**
