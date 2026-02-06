# Cyber-Squire CNS - Quick Start

## What Just Got Built

Your complete Central Nervous System for business automation. **8 workflows + deployment infrastructure.**

---

## Files Created

### Core Infrastructure
- `credentials_vault.json` - All API keys in one encrypted store
- `inject_credentials.sh` - Loads credentials into n8n
- `deploy_workflows.sh` - Deploys all 8 workflows

### Workflows (n8n JSON)
1. `workflow_api_healthcheck.json` - Monitors API health every 6 hours
2. `workflow_openclaw_generator.json` - Natural language → workflow creation
3. `workflow_gdrive_watcher.json` - Watches 2TB Google Drive for new files
4. `workflow_operation_nuclear.json` - Automated lead enrichment & outreach
5. `workflow_youtube_factory.json` - Video → transcript → metadata → shorts
6. `workflow_gumroad_solvency.json` - Sales tracking → debt reduction
7. `workflow_notion_task_manager.json` - ADHD-optimized task management
8. `workflow_ai_router.json` - Smart AI routing (Qwen → Gemini → Claude)

### Documentation
- `CNS_DEPLOYMENT_GUIDE.md` - Full architecture & deployment guide
- `QUICKSTART.md` - This file

---

## 3-Step Deployment

### 1. Start Infrastructure
```bash
cd /Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE
docker compose up -d
```

### 2. Inject Credentials
```bash
./inject_credentials.sh
```

### 3. Deploy Workflows
```bash
./deploy_workflows.sh
```

---

## Post-Deployment (Manual Steps)

### A. Complete Google OAuth

**IMPORTANT:** The docker-compose.yaml has been configured with the correct public URL for OAuth callbacks. Follow these steps:

**Step 1: Update Google Cloud Console**
```
1. Go to https://console.cloud.google.com
2. APIs & Services → Credentials
3. Edit OAuth 2.0 Client ID: 213586018316-c6iik0v8bc6qiknnh85i967gpscfbhkb
4. Under "Authorized redirect URIs":
   - Remove any localhost entries
   - Add: https://n8n.yourdomain.com/rest/oauth2-credential/callback
5. Save and wait 60 seconds
```

**Step 2: Connect in n8n**
```
1. Go to https://n8n.yourdomain.com
2. Credentials → "Google OAuth CoreDirective"
3. Verify redirect URL shows https://n8n.yourdomain.com/... (not localhost)
4. Click "Sign in with Google"
5. Authorize with your yourdomain.com account
```

**If you get a 400 error**, see [FIX_GOOGLE_OAUTH.md](FIX_GOOGLE_OAUTH.md) for detailed troubleshooting.

### B. Set Notion Database IDs

You need to create these Notion databases and add their IDs to each workflow:

**Required Databases:**
- Tasks DB (for Task Manager)
- Leads DB (for Operation Nuclear)
- Content DB (for YouTube Factory)
- Media DB (for Drive Watcher)
- Finance DB (for Gumroad Solvency)
- Transactions DB (for Gumroad Solvency)
- AI Log DB (for AI Router)

**How to get Database IDs:**
```
Notion URL: https://notion.so/workspace/abc123def456?v=...
Database ID: abc123def456
```

### C. Activate Workflows

In n8n UI, toggle "Active" for each workflow.

---

## Test Your Setup

### Test API Health Check
Wait 5 minutes, then check n8n executions. Should see green checkmarks for all APIs.

### Test AI Router
```bash
curl -X POST https://n8n.yourdomain.com/webhook/ai-router \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Explain quantum computing in 3 sentences",
    "complexity": "standard",
    "notion_ai_log_db": "YOUR_DB_ID"
  }'
```

Expected: Qwen processes (free), response returned, logged to Notion.

### Test Lead Enrichment
```bash
curl -X POST https://n8n.yourdomain.com/webhook/lead-intake \
  -H "Content-Type: application/json" \
  -d '{
    "company": "Test Corp",
    "contact_name": "John Doe",
    "contact_title": "CTO",
    "contact_email": "test@example.com",
    "linkedin_url": "https://linkedin.com/in/test",
    "company_url": "https://example.com",
    "notion_leads_db": "YOUR_DB_ID"
  }'
```

Expected: Perplexity researches → Claude drafts email → Saved to Notion with quality score.

---

## What Each System Does

### 🏥 API Health Check
- **Frequency:** Every 6 hours
- **Action:** Tests all 6 API credentials
- **On Failure:** Logs to Notion, creates alert

### 🤖 OpenClaw Workflow Generator
- **Trigger:** Webhook
- **Action:** Analyzes natural language request → Generates n8n workflow JSON → Creates workflow via API
- **AI Used:** Qwen (simple) or Claude (complex)

### 📂 Google Drive Watcher
- **Frequency:** Every 5 minutes
- **Action:** Scans `/data/media` for new files → Routes videos to YouTube Factory → Logs all to Notion
- **AI Used:** None (file system operations)

### ☢️ Operation Nuclear
- **Trigger:** Webhook (manual or automated lead import)
- **Action:** Perplexity researches company → Claude drafts personalized outreach → Auto-sends if score >= 8
- **AI Used:** Perplexity + Claude

### 🎬 YouTube Content Factory
- **Trigger:** Webhook (from Drive Watcher when video detected)
- **Action:** Extracts audio → Gemini transcribes → Qwen generates title/description/tags/shorts → Saves to Notion
- **AI Used:** Gemini + Qwen

### 💰 Gumroad Solvency Engine
- **Frequency:** Every hour
- **Action:** Fetches new sales → 60/30/10 allocation → Updates debt tracker → Sends thank you email
- **AI Used:** Qwen (thank you message)

### 📋 Notion Task Manager
- **Frequency:** Every 30 minutes
- **Action:** Analyzes active tasks → Qwen provides time estimates & subtasks → Claude prioritizes backlog → Generates daily strategy
- **AI Used:** Qwen + Claude

### 🧠 AI Intelligence Router
- **Trigger:** Webhook (called by other workflows or OpenClaw)
- **Action:** Analyzes request complexity/context → Routes to Qwen (default), Gemini (large context), or Claude (strategic)
- **AI Used:** All three, intelligently routed

---

## Cost Optimization

### Current Setup
- **90% of requests → Qwen (local, $0)**
- **8% of requests → Gemini (~$5/month)**
- **2% of requests → Claude (~$20/month)**

### If You Want to Reduce Claude Costs Further
Edit `workflow_ai_router.json`:
```javascript
// Change routing threshold
if (complexity === 'strategic' || priority === 'critical') {
  // Add additional check:
  if (context_size < 50000) {
    route = 'gemini';  // Use Gemini instead of Claude for smaller strategic tasks
  } else {
    route = 'claude';
  }
}
```

---

## Monitoring Your System

### Daily Check (30 seconds)
1. Open https://n8n.yourdomain.com
2. Check "Executions" tab - should see green checkmarks
3. Open Notion - check daily strategy page

### Weekly Review (10 minutes)
1. Review AI Log DB - check Qwen/Gemini/Claude distribution
2. Review Leads DB - check personalization scores & conversion rate
3. Review Finance DB - check debt reduction progress
4. Review Content DB - check video processing success rate

### Monthly Audit (1 hour)
1. Rotate API keys (see CNS_DEPLOYMENT_GUIDE.md)
2. Export PostgreSQL backup
3. Export n8n workflows (version control)
4. Analyze cost vs revenue trends

---

## Troubleshooting

### "Workflow execution failed"
- Check n8n execution logs for specific error
- Verify Notion database IDs are correct
- Ensure API credentials are active

### "No new files detected" (Drive Watcher)
- Verify Google Drive is mounted at `/data/media`
- Check file modification timestamps
- Test: `docker exec cd-service-n8n ls -la /data/media`

### "AI Router always uses Claude"
- Check routing logic in workflow
- Verify Ollama is running: `docker ps | grep ollama`
- Test Qwen: `curl http://localhost:11434/api/generate -d '{"model":"qwen3:8b-instruct-q4_K_M","prompt":"test"}'`

### "Gumroad sales not tracking"
- Verify Gumroad API key in credentials_vault.json
- Check Gumroad API status: https://gumroad.com/api
- Test webhook: `curl https://api.gumroad.com/v2/sales` with your API key

---

## Telegram Bots (Active)

Two bots are live:

### @CDirective_bot (OpenClaw - Primary)
- **Engine:** OpenClaw Gateway (openclaw-gateway container)
- **Model:** Claude Sonnet 4.5 → Opus 4.5 fallback
- **Capabilities:** Autonomous agent, browser control, multi-step tasks
- **Config:** `~/openclaw/config/openclaw.json`
- **Auth:** `~/openclaw/config/agents/main/agent/auth-profiles.json`

### @Coredirective_bot (n8n - Basic)
- **Engine:** n8n webhook workflow
- **Model:** Ollama/Qwen 2.5:7b (local, free)
- **Tools:** ADHD Commander, Finance Manager, System Status
- **Workflow:** `workflow_supervisor_agent.json`

---

## Support

**Full Documentation:** `CNS_DEPLOYMENT_GUIDE.md`
**Architecture Details:** See "Architecture Overview" section in guide
**Security Best Practices:** See "Security Best Practices" section

**Status: Production - Two bots active, full stack running.**
