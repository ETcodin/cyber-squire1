# Phase 3 Quick Start Guide

**For:** Developers/agents executing Phase 3: AI Routing Core
**Time Estimate:** 4-6 hours (including testing)

---

## Execution Order

### Wave 1 (Run in parallel)

1. **03-01-PLAN.md** — AI Agent Routing Configuration
   - Updates: `workflow_supervisor_agent.json`
   - Tasks: 4 automated tasks
   - Output: Enhanced system prompt, routing logs, test cases
   - Estimated time: 1 hour

2. **03-02-PLAN.md** — Tool Schema Definitions
   - Updates: `workflow_supervisor_agent.json`, tool workflows
   - Tasks: 4 automated tasks
   - Output: System Status tool connected, optimized descriptions
   - Estimated time: 1 hour

### Wave 2 (Sequential, after Wave 1)

3. **03-03-PLAN.md** — Confidence & Fallback Logic
   - Updates: `workflow_supervisor_agent.json`, SQL schema
   - Tasks: 4 automated tasks
   - Output: Fallback handling, enhanced logging, fallback tests
   - Depends on: 03-01
   - Estimated time: 1.5 hours

### Wave 3 (Checkpoint, after all above)

4. **03-04-PLAN.md** — Testing & Validation
   - Updates: Results documentation
   - Tasks: 5 tasks (2 manual, 3 automated)
   - Output: Test results, latency metrics, phase completion status
   - Depends on: 03-01, 03-02, 03-03
   - **Requires:** Human tester with Telegram access
   - Estimated time: 2-3 hours

---

## Prerequisites

- [ ] Phase 2 completed (webhook and message intake working)
- [ ] n8n accessible at https://cyber-squire.tigouetheory.com
- [ ] Ollama running with qwen2.5:7b model
- [ ] KEEP_ALIVE=24h configured (from Phase 1)
- [ ] Telegram bot token configured in n8n credentials
- [ ] SSH access to EC2 (54.234.155.244)

---

## Quick Commands

### Execute Plans (Wave 1 & 2)
```bash
# From project root
cd /Users/et/cyber-squire-ops

# Execute plans sequentially
# 03-01 and 03-02 can run in parallel if using multiple agents
```

### Deploy to Production (Before 03-04)
```bash
# Transfer workflows
scp -i ~/.ssh/cyber-squire-key.pem \
    COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json \
    COREDIRECTIVE_ENGINE/workflow_tool_system_status.json \
    ec2-user@54.234.155.244:/tmp/

# SSH to EC2
ssh -i ~/.ssh/cyber-squire-key.pem ec2-user@54.234.155.244

# Monitor n8n logs
docker logs -f cd-service-n8n 2>&1 | grep "ROUTING_DECISION"
```

### Run Tests (Wave 3)
```bash
# Send test messages via Telegram to @Coredirective_bot
# Examples:
# - "Check system health"
# - "What's on my plate today?"
# - "asdfghjkl"

# Check execution logs in n8n UI
# https://cyber-squire.tigouetheory.com
```

---

## Expected Outputs

After each plan completes, you should have:

### 03-01
- ✅ `workflow_supervisor_agent.json` with ROUTING RULES in system prompt
- ✅ `log-routing-decision` Code node inserted
- ✅ `03-01-TEST-CASES.md` created

### 03-02
- ✅ System Status tool node added to Supervisor workflow
- ✅ ADHD Commander & Finance Manager descriptions enhanced
- ✅ `03-02-DEPLOYMENT.md` guide created

### 03-03
- ✅ FALLBACK HANDLING section in system prompt
- ✅ Enhanced confidence scoring in logs
- ✅ `routing_metrics.sql` schema created
- ✅ `03-03-TEST-CASES.md` created

### 03-04
- ✅ Workflows deployed to production n8n
- ✅ 26 test cases executed
- ✅ Latency measured (average <3s)
- ✅ `03-04-RESULTS.md` with pass/fail status
- ✅ All 5 success criteria validated

---

## Success Indicators

### During Execution
- [ ] No JSON syntax errors in workflow files
- [ ] All grep verification commands pass
- [ ] n8n workflow imports without errors
- [ ] Test messages receive responses (not errors)

### At Completion
- [ ] 18/20 routing tests pass (90% accuracy)
- [ ] 14/16 fallback tests pass (87% graceful degradation)
- [ ] Average latency <3 seconds
- [ ] ROUTING_DECISION logs visible in n8n
- [ ] All success criteria SC-3.1 through SC-3.5 validated

---

## Troubleshooting

### Issue: Tool not appearing in n8n
**Fix:** Check workflow ID is correct, verify ai_tool connection in JSON

### Issue: Routing latency >3 seconds
**Fix:** Verify Ollama KEEP_ALIVE=24h, check context window size (should be 13)

### Issue: Test cases failing routing
**Fix:** Review system prompt, adjust examples, consider temperature tuning

### Issue: n8n workflow import fails
**Fix:** Validate JSON syntax, check for missing credentials

---

## Validation Checklist

Before marking Phase 3 complete:

- [ ] All 4 plans executed successfully
- [ ] All plan SUMMARY files created
- [ ] Test results documented in 03-04-RESULTS.md
- [ ] At least 4/5 success criteria passed
- [ ] Workflow metadata updated to v3.0.0
- [ ] ROADMAP.md phase 3 checkboxes marked

---

## Next Steps After Phase 3

If Phase 3 passes:
1. Review 03-04-RESULTS.md for any issues to address
2. Update ROADMAP.md with completion date
3. Proceed to Phase 4: Memory & Context

If Phase 3 fails:
1. Identify which success criteria failed
2. Create remediation tasks
3. Re-test before proceeding

---

*Quick reference for Phase 3 execution | Updated: 2026-02-04*
