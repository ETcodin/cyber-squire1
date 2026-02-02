# Cyber-Squire CNS Deployment Guide

**Central Nervous System for Business Automation**

---

## Architecture Overview

The Cyber-Squire CNS is a **sovereign business operating system** designed to maximize output while accommodating physical constraints (Sickle Cell RO). It operates on a **Bridge Architecture** where all services communicate through a private Docker bridge network (`cd-net`) with Zero Trust security.

### Core Principles

1. **Zero Open Ports**: All external access via Cloudflare Tunnel
2. **Tiered AI Intelligence**: Qwen (90%) → Gemini (large context) → Claude (strategic)
3. **2TB Google Drive Bridge**: No AWS storage costs
4. **Deep Work Optimization**: Removes friction from routine tasks
5. **Debt-to-Solvency Pipeline**: Automated financial tracking

---

## Infrastructure Stack

### Services (docker-compose.yaml)

- **cd-service-db** (PostgreSQL 16): Business memory & workflow state
- **cd-service-n8n**: Orchestration engine with encrypted credentials
- **cd-service-ollama**: Local Qwen 3 instance (zero-cost AI)
- **tunnel-cyber-squire** (Cloudflare): Zero Trust gateway

### Security Layers

1. **SELinux Enforcement**: Container isolation with `svirt_sandbox_file_t`
2. **Encrypted Secrets**: AES-256 encryption for API keys (via `CD_N8N_KEY`)
3. **No Direct Internet Exposure**: All traffic through Cloudflare Tunnel
4. **Persistent Volumes**: `:z` flag for SELinux context preservation

---

## Deployment Process

### Phase 1: Infrastructure Preparation

```bash
# Start the CoreDirective stack
cd /Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE
docker compose up -d

# Verify services are healthy
docker ps | grep cd-service
```

### Phase 2: Credential Injection

```bash
# Inject all API credentials into n8n
./inject_credentials.sh
```

**What gets injected:**
- Claude AI (Anthropic)
- GitHub CoreDirective
- Google OAuth CoreDirective
- Gumroad Sales API
- Notion Cyber-Squire API
- Perplexity API (PPLX)

### Phase 3: Workflow Deployment

```bash
# Deploy all CNS workflows
./deploy_workflows.sh
```

**8 Workflows Deployed:**

1. **🏥 API Health Check** - Monitors all API credentials every 6 hours
2. **🤖 Moltbot Workflow Generator** - Natural language → n8n workflow JSON
3. **📂 Google Drive File Watcher** - Monitors 2TB mount for new files
4. **☢️ Operation Nuclear** - Lead enrichment → Claude outreach → Auto-send
5. **🎬 YouTube Content Factory** - Video → Transcript → Metadata → Shorts scripts
6. **💰 Gumroad Solvency Engine** - Sales → 60/30/10 allocation → Debt tracker
7. **📋 Notion Task Manager** - ADHD-optimized task analysis & prioritization
8. **🧠 AI Intelligence Router** - Smart routing to Qwen/Gemini/Claude

### Phase 4: Manual Configuration

#### 1. Google OAuth Completion

```
1. Navigate to https://n8n.yourdomain.com
2. Go to Credentials → "Google OAuth CoreDirective"
3. Click "Connect my account"
4. Authorize with your Google account
```

#### 2. Set Notion Database IDs

Each workflow needs specific Notion database IDs. Update these in the n8n UI:

**Task Manager Workflow:**
- `notion_tasks_db` - Your Tasks database ID
- `notion_strategy_page` - Daily strategy page ID

**Operation Nuclear Workflow:**
- `notion_leads_db` - Leads database ID

**YouTube Factory Workflow:**
- `notion_content_db` - Content dashboard database ID
- `notion_shorts_db` - Shorts scripts database ID

**Drive Watcher Workflow:**
- `notion_media_db` - Media library database ID

**Gumroad Solvency Workflow:**
- `notion_finance_db` - Financial tracker database ID
- `notion_transactions_db` - Transaction log database ID
- `notion_milestones_page` - Milestones page ID

**AI Router Workflow:**
- `notion_ai_log_db` - AI usage log database ID

#### 3. Activate Workflows

```
1. In n8n UI, go to each workflow
2. Toggle "Active" switch to enable
3. Test webhook endpoints (see below)
```

---

## Webhook Endpoints

All webhooks are accessible via Cloudflare Tunnel:

### Moltbot Workflow Generator
```bash
curl -X POST https://n8n.yourdomain.com/webhook/moltbot-command \
  -H "Content-Type: application/json" \
  -d '{
    "command": "Create a workflow that checks Twitter mentions every hour",
    "notion_log_page": "YOUR_NOTION_PAGE_ID"
  }'
```

### Operation Nuclear Lead Intake
```bash
curl -X POST https://n8n.yourdomain.com/webhook/lead-intake \
  -H "Content-Type: application/json" \
  -d '{
    "company": "Acme Corp",
    "contact_name": "Jane Smith",
    "contact_title": "CTO",
    "contact_email": "jane@acme.com",
    "linkedin_url": "https://linkedin.com/in/janesmith",
    "company_url": "https://acme.com",
    "notion_leads_db": "YOUR_NOTION_DB_ID"
  }'
```

### YouTube Content Factory
```bash
curl -X POST https://n8n.yourdomain.com/webhook/youtube-content-factory \
  -H "Content-Type: application/json" \
  -d '{
    "file_path": "/data/media/videos/my_video.mp4",
    "filename": "my_video",
    "size_bytes": 524288000,
    "notion_content_db": "YOUR_NOTION_DB_ID",
    "notion_shorts_db": "YOUR_NOTION_DB_ID"
  }'
```

### AI Intelligence Router
```bash
curl -X POST https://n8n.yourdomain.com/webhook/ai-router \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Analyze this company for security vulnerabilities",
    "context_size": 5000,
    "complexity": "standard",
    "priority": "standard",
    "notion_ai_log_db": "YOUR_NOTION_DB_ID"
  }'
```

---

## AI Routing Logic

### Qwen 3 (Local via Ollama) - 90% of requests
**Cost:** $0
**Use Cases:**
- Task analysis & metadata generation
- Simple outreach drafts
- File categorization
- Thank you emails

**Routes automatically when:**
- `complexity != 'strategic'`
- `priority != 'critical'`
- `context_size < 100,000 tokens`

### Gemini 2.0 Flash
**Cost:** ~$0.10 per 1M tokens
**Use Cases:**
- Video transcription
- Large PDF analysis
- 500+ page document processing

**Routes automatically when:**
- `context_size > 100,000 tokens`
- Prompt contains "video transcript" or "analyze document"

### Claude 3.5 Sonnet
**Cost:** ~$3 per 1M tokens
**Use Cases:**
- Operation Nuclear outreach drafting
- Complex technical documentation
- Strategic business planning
- Code architecture decisions

**Routes automatically when:**
- `complexity == 'strategic'`
- `priority == 'critical'`
- `complexity == 'complex' AND priority == 'high'`

---

## Operation Nuclear Workflow

### Lead Enrichment Pipeline

```
Lead Intake → Perplexity Research → Claude Draft → Notion Save → Quality Check
                                                                        ↓
                                                    Score >= 8? → Auto-Send
                                                    Score < 8?  → Manual Review
```

### Quality Score Thresholds

- **8-10**: Auto-send (high personalization, strong business context)
- **5-7**: Manual review required
- **< 5**: Rejected, re-draft needed

### Personalization Factors

Claude evaluates:
1. Company-specific context usage
2. Technical accuracy
3. Value proposition clarity
4. CTA strength
5. Tone appropriateness

---

## YouTube Content Factory

### Full Pipeline

```
Video Upload (Google Drive) → ffmpeg Audio Extract → Gemini Transcript
                                                           ↓
                                              Qwen Metadata Generation
                                                           ↓
                                    [Title, Description, Tags, 5x Shorts Scripts]
                                                           ↓
                                              Notion Content Dashboard
```

### Outputs

**Main Video:**
- SEO-optimized title (< 70 chars)
- 3-paragraph description with keywords
- 10 relevant tags
- Full transcript with timestamps

**Shorts Scripts (5x):**
- 15-30 second variations
- Platform-specific (TikTok, YT Shorts, IG Reels)
- Hook-driven opening
- Clear CTA

---

## Gumroad Solvency Engine

### Financial Allocation (60/30/10 Rule)

Every Gumroad sale is automatically split:

- **60% → Debt Payment** (Target: $60k → $0)
- **30% → Reinvestment** (Infrastructure, tools, ads)
- **10% → Reserve Fund** (Emergency buffer)

### Debt Tracking

**Initial Debt:** $60,000
**Current Debt:** Updated hourly via Notion
**Progress Tracking:** Percentage completion
**Milestone Celebrations:** Auto-logged at 25%, 50%, 75%, 100%

### Customer Retention

1. Qwen generates personalized thank you message
2. Gmail sends automated email
3. Increases customer lifetime value & referrals

---

## Notion Task Manager (ADHD Optimization)

### Features

1. **Time Estimation**: Realistic task completion times
2. **Subtask Breakdown**: 3-5 actionable items per task
3. **Blocker Identification**: Potential friction points
4. **Deep Work Windows**: Best time-of-day recommendations
5. **Daily Strategy**: Claude-powered prioritization

### Batching Strategy

Claude analyzes high-priority backlog and suggests:
- Which tasks can be batched together
- Which tasks should be automated
- Which tasks need delegation
- Optimal daily schedule based on energy levels

---

## Moltbot Integration

### Natural Language Workflow Creation

```
User: "Create a workflow that posts to Twitter when I publish a YouTube video"
       ↓
Qwen analyzes request
       ↓
Determines: trigger=YouTube RSS, action=Twitter API
       ↓
Routes to Claude (if complex) or Qwen (if simple)
       ↓
Generates valid n8n workflow JSON
       ↓
POSTs to n8n API → Workflow created & activated
```

### Mobile Control

Text Moltbot from WhatsApp/Telegram:
```
"Check if my workflows are running"
"Show me today's leads"
"Generate a thank you email for the last Gumroad customer"
```

Moltbot triggers relevant n8n workflows and returns results.

---

## Monitoring & Maintenance

### Health Check Workflow

Runs every 6 hours to test:
- Anthropic API
- GitHub API
- Notion API
- Gumroad API
- Perplexity API
- Google OAuth status

**On Failure:**
- Logs error to Notion
- Creates alert page
- Can trigger notification via Moltbot

### Log Analysis

All AI requests logged to Notion:
- Model used
- Routing reason
- Prompt preview
- Response preview
- Timestamp

**Use this data to:**
- Track costs (Claude vs Qwen usage)
- Identify bottlenecks
- Optimize routing logic

---

## Cost Projections

### Monthly Operating Costs

**Fixed Infrastructure:**
- AWS RHEL 9 instance: ~$40/month
- Cloudflare Tunnel: $0 (free tier)
- Google Drive 2TB: $10/month
- PostgreSQL (local): $0

**API Usage (Projected):**
- Anthropic Claude: ~$20/month (strategic tasks only)
- Google Gemini: ~$5/month (transcriptions)
- Perplexity: ~$10/month (lead research)
- Qwen/Ollama: $0 (local)

**Total: ~$85/month**

### Break-Even Analysis

**Cyber-Squire OS Product:** $47/sale
**Break-even:** 2 sales/month
**Target Revenue:** $120k-$170k/year
**Required Sales:** 2,553-3,617 sales/year (~7-10 sales/day)

---

## Troubleshooting

### n8n Won't Start
```bash
# Check Docker logs
docker logs cd-service-n8n

# Verify PostgreSQL is healthy
docker exec cd-service-db pg_isready -U ${CD_DB_USER}

# Restart services
docker compose down && docker compose up -d
```

### Credentials Not Injecting
```bash
# Verify credentials_vault.json exists
cat credentials_vault.json | jq .

# Check n8n API accessibility
curl http://localhost:5678/healthz

# Re-run injection script with verbose output
bash -x ./inject_credentials.sh
```

### Workflow Fails to Deploy
```bash
# Validate JSON syntax
jq . workflow_name.json

# Check n8n API logs
docker logs cd-service-n8n | grep ERROR

# Manually import via n8n UI as fallback
```

### Google OAuth Fails
```bash
# Common issues:
# 1. Redirect URI mismatch in Google Cloud Console
#    Should be: https://n8n.yourdomain.com/rest/oauth2-credential/callback

# 2. OAuth consent screen not configured
#    Go to: console.cloud.google.com → OAuth consent screen

# 3. Scopes not enabled
#    Required: Gmail, Google Sheets, YouTube Data API v3
```

---

## Security Best Practices

### Credential Rotation Schedule

**Every 90 Days:**
- Anthropic API key
- GitHub PAT
- Notion API key
- Perplexity API key

**Every 180 Days:**
- Google OAuth client secret
- Gumroad API credentials
- n8n API key (`CD_N8N_KEY`)

### Backup Strategy

```bash
# Daily PostgreSQL backup (automated)
docker exec cd-service-db pg_dump -U ${CD_DB_USER} ${CD_DB_NAME} > ./CD_BACKUPS/backup_$(date +%Y%m%d).sql

# Weekly n8n workflow export
curl -H "X-N8N-API-KEY: ${CD_N8N_KEY}" \
     http://localhost:5678/api/v1/workflows > workflows_backup.json
```

### SELinux Audit

```bash
# Check for denials
ausearch -m avc -ts recent

# If denials found, adjust container labels
chcon -Rt svirt_sandbox_file_t ./CD_VOL_N8N
```

---

## Next Steps

### Phase 5: Moltbot Mobile Bridge

Build the mobile interface for WhatsApp/Telegram control.

**Components:**
1. Twilio WhatsApp Business API integration
2. Telegram Bot API connection
3. NLP parser (Qwen) to interpret commands
4. n8n webhook triggers

### Phase 6: Revenue Optimization

1. A/B test Gumroad product pricing
2. Automate upsell sequences
3. Implement affiliate tracking
4. Build referral reward system

### Phase 7: Scale Operations

1. Hire virtual assistant for manual review queue
2. Expand Operation Nuclear to 50 leads/day
3. Launch YouTube content cadence (3x/week)
4. Build community around Cyber-Squire methodology

---

## Support & Documentation

**GitHub Issues:** [Report problems or request features]
**Notion Knowledge Base:** [Internal documentation]
**Video Walkthroughs:** [Coming soon to YouTube channel]

**Built with sovereignty. Operated with precision.**

---

**© 2026 Cyber-Squire Operations | Tigou E Theory**
