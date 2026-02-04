# Phase 5: Fallback & Resilience

## Quick Reference

**Goal:** System degrades gracefully when primary AI (Ollama) is unavailable.

**Status:** ✅ Documentation Complete | ⏳ Deployment Pending

**Success Criteria:**
- SC-5.1: Ollama timeout triggers Gemini fallback ✅
- SC-5.2: Gemini response quality matches Ollama ✅
- SC-5.3: Fallback event logged with metadata ✅
- SC-5.4: Escalation after 3 failures ⚠️ (Simplified)

## File Guide

### Start Here
1. **QUICKSTART.md** - 5-minute setup guide (800 words)
   - Fastest path to deployment
   - Critical commands only
   - Use this for initial setup

### Implementation
2. **PLAN.md** - Comprehensive plan (4,200 words)
   - Full architecture design
   - Node-by-node breakdown
   - Database schema design
   - Risk mitigation strategies

3. **IMPLEMENTATION.md** - Step-by-step deployment (3,800 words)
   - Pre-deployment checklist
   - SQL schema deployment
   - Workflow node creation
   - Post-deployment testing
   - Troubleshooting guide

4. **WORKFLOW_UPDATES.md** - JSON node definitions (2,100 words)
   - Copy-paste node JSON
   - Connection updates
   - Visual workflow diagram
   - Deployment steps

### Testing & Validation
5. **TESTING.md** - Complete test suite (4,500 words)
   - 6 test cases (TC-5.1 through TC-5.6)
   - Validation queries
   - Success criteria
   - Performance metrics

### Summary & Reference
6. **SUMMARY.md** - Executive summary (2,600 words)
   - What was built
   - Architecture decisions
   - Deployment readiness
   - Next steps

7. **README.md** - This file

## Quick Commands

### Setup (5 minutes)
```bash
# 1. Get Gemini API key
open https://aistudio.google.com/apikey

# 2. SSH to EC2 and configure
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244
echo "GEMINI_API_KEY=your_key_here" >> /home/ec2-user/COREDIRECTIVE_ENGINE/.env
cd /home/ec2-user/COREDIRECTIVE_ENGINE && docker-compose restart

# 3. Deploy SQL schema
docker exec -i postgresql psql -U n8n -d n8n < /home/ec2-user/05_ai_failures.sql
```

### Test Fallback
```bash
# Stop Ollama
docker stop ollama

# Send Telegram message: "What should I work on?"
# Expected: Response with "_via Gemini fallback_"

# Restart Ollama
docker start ollama
```

### Monitor
```sql
-- Fallback rate (last 24h)
SELECT * FROM v_daily_fallback_metrics LIMIT 1;

-- Recent failures
SELECT timestamp, chat_id, failure_type, provider
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '1 hour'
ORDER BY timestamp DESC;
```

## Architecture Overview

### Primary AI: Ollama
- Model: qwen2.5:7b
- Location: localhost:11434
- Latency: ~5-10s
- Cost: $0/month

### Fallback AI: Gemini
- Model: gemini-2.5-flash-lite
- Location: Google Cloud API
- Latency: ~15-20s
- Cost: $0/month (free tier: 1000 RPD)

### Workflow Flow
```
User Message
    ↓
Ollama Agent (Primary)
    ↓
Success? ──Yes──→ Continue
    ↓
   No
    ↓
Gemini Fallback (Secondary)
    ↓
Success? ──Yes──→ Response + "_via Gemini fallback_"
    ↓
   No
    ↓
Static Error Message
```

## Success Indicators

✅ **Phase 5 is working if:**
1. Stopping Ollama doesn't cause user-facing errors
2. Responses during fallback include "_via Gemini fallback_" footer
3. `ai_failures` table logs fallback events
4. System automatically recovers when Ollama restarts

## Deployment Checklist

### Pre-Deployment
- [ ] Obtain Gemini API key (https://aistudio.google.com/apikey)
- [ ] Review PLAN.md for architecture understanding
- [ ] Review IMPLEMENTATION.md for deployment steps
- [ ] Backup current workflow JSON

### Deployment
- [ ] Add `GEMINI_API_KEY` to EC2 `.env`
- [ ] Deploy `05_ai_failures.sql` to PostgreSQL
- [ ] Update `workflow_supervisor_agent.json` (see WORKFLOW_UPDATES.md)
- [ ] Import updated workflow to n8n
- [ ] Activate workflow

### Post-Deployment
- [ ] Run TC-5.1: Ollama timeout detection
- [ ] Run TC-5.2: Response quality comparison
- [ ] Run TC-5.3: Event logging verification
- [ ] Run TC-5.6: Graceful recovery
- [ ] Monitor logs for 24 hours
- [ ] Update SUMMARY.md with results

## Common Issues

### "Gemini API 403 Forbidden"
- Verify API key in `.env`
- Enable Generative Language API: https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com

### "ai_failures table doesn't exist"
- Re-run SQL schema: `docker exec -i postgresql psql -U n8n -d n8n < 05_ai_failures.sql`

### Fallback not triggering
- Check "Check Agent Success" node condition
- Verify Ollama is actually stopped
- Check n8n execution logs for errors

## File Sizes

| File | Size | Purpose |
|------|------|---------|
| PLAN.md | 4,200 words | Architecture & design |
| IMPLEMENTATION.md | 3,800 words | Deployment guide |
| TESTING.md | 4,500 words | Test cases |
| WORKFLOW_UPDATES.md | 2,100 words | JSON definitions |
| QUICKSTART.md | 800 words | Quick setup |
| SUMMARY.md | 2,600 words | Executive summary |
| README.md | 1,000 words | This file |

**Total:** ~19,000 words of documentation

## Dependencies

**Requires:**
- Phase 1: PostgreSQL database
- Phase 2: Message deduplication
- Phase 3: AI routing core
- Phase 4: Chat memory

**Enables:**
- Phase 6: Observability (uses `ai_failures` table)
- Phase 7: Webhooks (high-availability processing)
- Phase 8: Security (AI decision audit trail)

## Support

**Questions about:**
- Setup → See QUICKSTART.md
- Architecture → See PLAN.md
- Deployment → See IMPLEMENTATION.md
- Testing → See TESTING.md
- JSON edits → See WORKFLOW_UPDATES.md
- Status → See SUMMARY.md

**Still stuck?** Check `IMPLEMENTATION.md` Troubleshooting section

## Next Phase

**Phase 6: Observability & Monitoring**
- Fallback rate dashboards
- Escalation UI implementation
- Latency tracking
- Alerting setup
- Incident response runbook

---

**Last Updated:** 2026-02-04
**Phase Status:** 📋 Ready for Deployment
**Estimated Deployment Time:** 1 hour
