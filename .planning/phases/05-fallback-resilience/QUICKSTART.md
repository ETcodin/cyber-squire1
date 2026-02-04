# Phase 5: Fallback & Resilience - Quick Start Guide

## 5-Minute Setup

### 1. Get Gemini API Key (2 min)
```bash
# Visit: https://aistudio.google.com/apikey
# Click "Create API Key"
# Copy key to clipboard
```

### 2. Configure Environment (1 min)
```bash
# SSH to EC2
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244

# Add to .env
echo "GEMINI_API_KEY=your_key_here" >> /home/ec2-user/COREDIRECTIVE_ENGINE/.env

# Restart containers
cd /home/ec2-user/COREDIRECTIVE_ENGINE
docker-compose restart
```

### 3. Deploy Database Schema (1 min)
```bash
# Copy SQL file to EC2
scp -i ~/cyber-squire-ops/cyber-squire-ops.pem \
  /Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/sql/05_ai_failures.sql \
  ec2-user@54.234.155.244:/home/ec2-user/

# Execute on PostgreSQL
docker exec -i postgresql psql -U n8n -d n8n < /home/ec2-user/05_ai_failures.sql

# Verify
docker exec -it postgresql psql -U n8n -d n8n -c "\d ai_failures"
```

### 4. Update Workflow (1 min)
```bash
# Import updated workflow_supervisor_agent.json via n8n UI
# http://54.234.155.244:5678
# Workflows → "Telegram Supervisor Agent" → ... → Import from File
# Upload: /Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json
```

### 5. Test Fallback (30 sec)
```bash
# Stop Ollama
docker stop ollama

# Send Telegram message: "What should I work on?"
# Expected: Response with "_via Gemini fallback_" footer

# Restart Ollama
docker start ollama
```

## Critical Endpoints

### Monitoring Queries
```sql
-- Fallback rate (last 24h)
SELECT * FROM v_daily_fallback_metrics ORDER BY day DESC LIMIT 1;

-- Current escalations
SELECT * FROM v_escalation_status;

-- Recent failures
SELECT timestamp, chat_id, failure_type, provider
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '1 hour'
ORDER BY timestamp DESC;
```

### Troubleshooting Commands
```bash
# Check Ollama health
docker ps | grep ollama
curl http://localhost:11434/api/tags

# Check n8n logs for fallback events
docker logs n8n --tail 100 | grep -i "fallback"

# Verify Gemini API key
docker exec -it n8n sh
echo $GEMINI_API_KEY

# Test Gemini API directly
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=YOUR_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"test"}]}]}'
```

## Success Indicators

✅ **Phase 5 Working If:**
1. Stopping Ollama triggers Gemini fallback (no user-facing errors)
2. Fallback responses include "_via Gemini fallback_" footer
3. `ai_failures` table has entries after fallback events
4. 3 consecutive failures show escalation message
5. Restarting Ollama returns to primary AI (no fallback indicator)

## Common Issues

### Issue: "Gemini API 403 Forbidden"
**Fix:**
- Verify API key: `cat /home/ec2-user/COREDIRECTIVE_ENGINE/.env | grep GEMINI`
- Enable API: https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com

### Issue: "ai_failures table doesn't exist"
**Fix:**
- Re-run schema: `docker exec -i postgresql psql -U n8n -d n8n < 05_ai_failures.sql`

### Issue: Fallback not triggering
**Fix:**
- Check "Check Agent Success" node condition
- Verify workflow connections in n8n UI
- Check n8n execution logs for errors

### Issue: Escalation spam
**Fix:**
- Increase threshold in workflow (change 3 to 5)
- Verify auto-resolve trigger: `SELECT tgname FROM pg_trigger WHERE tgrelid='ai_failures'::regclass;`

## Next Steps

1. ✅ Run full test suite: See `TESTING.md`
2. ✅ Set up monitoring dashboard
3. ✅ Configure alerting (Telegram/email for escalations)
4. ✅ Document in `SUMMARY.md` when complete

## Reference Files

- **Full Plan:** `PLAN.md`
- **Implementation:** `IMPLEMENTATION.md`
- **Testing:** `TESTING.md`
- **SQL Schema:** `/COREDIRECTIVE_ENGINE/sql/05_ai_failures.sql`
- **Workflow:** `/COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json`
