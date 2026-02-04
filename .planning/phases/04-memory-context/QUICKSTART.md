# Phase 4: Memory & Context - Quick Start Guide

**Goal**: Deploy PostgreSQL chat memory in 10 minutes

---

## Prerequisites
```bash
# Verify EC2 access
ssh -i ~/.ssh/cyber-squire-ops.pem ubuntu@54.234.155.244 "echo connected"

# Verify PostgreSQL running
ssh -i ~/.ssh/cyber-squire-ops.pem ubuntu@54.234.155.244 "docker ps | grep cd-service-db"
```

---

## Deploy in 3 Steps

### Step 1: Deploy Schema (3 minutes)
```bash
cd /Users/et/cyber-squire-ops/.planning/phases/04-memory-context
./deploy.sh
```

**Expected Output**:
```
[INFO] ✓ Table created
[INFO] ✓ Indexes created (3)
[INFO] ✓ Auto-pruning trigger created
[INFO] ✓ Functions created (3)
[INFO] Deployment complete!
```

---

### Step 2: Run Tests (5 minutes)
```bash
./test.sh
```

**Expected Output**:
```
Tests Passed:  6
Tests Failed:  0
Tests Skipped: 0
Pass Rate: 100%
All tests passed!
```

---

### Step 3: Validate via Telegram (2 minutes)

**Test 1: Simple Context**
```
You: I need to deploy Phase 4
Bot: I can help with that...
You: Add that task
Bot: ✓ Added "deploy Phase 4"  ← Should work!
```

**Test 2: Multi-Turn**
```
You: What should I focus on?
Bot: [Returns task list]
You: How long will the first task take?
Bot: [References first task from previous message]  ← Should work!
```

---

## Success Criteria Checklist

- [ ] SC-4.1: "Add that task" works (references prior message)
- [ ] SC-4.2: Context shows 13 messages (automated test passes)
- [ ] SC-4.3: Memory persists after restart
- [ ] SC-4.4: Auto-pruning works (automated test passes)

---

## Troubleshooting

### Problem: Tests Fail
```bash
# Check PostgreSQL logs
ssh ubuntu@54.234.155.244 'docker logs cd-service-db --tail 50'

# Re-deploy schema
./deploy.sh
```

### Problem: Context Not Working
```bash
# Check if messages are stored
ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT COUNT(*) FROM chat_memory;"'

# If 0 → verify workflow connection in n8n UI
```

### Problem: Performance Issues
```bash
# Check query performance
ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
EXPLAIN ANALYZE SELECT * FROM chat_memory ORDER BY created_at DESC LIMIT 13;
"'

# Should be < 10ms
```

---

## Rollback (if needed)

**Option 1: Disable Memory (keeps workflow running)**
1. Open n8n UI: http://54.234.155.244:5678
2. Workflow: "Telegram Supervisor Agent"
3. Disconnect Chat Memory node from Supervisor Agent
4. Save workflow

**Option 2: Drop Table (nuclear)**
```bash
ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "DROP TABLE IF EXISTS chat_memory CASCADE;"'
```

---

## Next Steps

After deployment:
1. Monitor for 24 hours
2. Check memory stats: `SELECT * FROM chat_memory_stats;`
3. Collect user feedback on context awareness
4. Review SUMMARY.md for detailed metrics

---

## Files Reference

| File | Purpose |
|------|---------|
| `QUICKSTART.md` | This guide (10-minute deployment) |
| `SUMMARY.md` | Executive summary & metrics |
| `PLAN.md` | Detailed implementation plan |
| `IMPLEMENTATION.md` | Step-by-step technical guide |
| `TESTING.md` | Comprehensive test suite |
| `CONTEXT_EXAMPLES.md` | Real-world usage examples |
| `deploy.sh` | Automated deployment script |
| `test.sh` | Automated test runner |

---

**Total Time**: 10 minutes
**Risk Level**: Low (quick rollback available)
**Impact**: High (enables natural conversations)
