# Phase 4: Memory & Context - Execution Checklist

Use this checklist to track deployment progress and ensure all success criteria are met.

---

## Pre-Deployment Checklist

### Infrastructure Verification
- [ ] EC2 instance accessible via SSH
  ```bash
  ssh -i ~/.ssh/cyber-squire-ops.pem ubuntu@54.234.155.244 "echo connected"
  ```
- [ ] PostgreSQL container running
  ```bash
  ssh ubuntu@54.234.155.244 "docker ps | grep cd-service-db"
  ```
- [ ] Database `cd_automation_db` exists
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -lqt | grep cd_automation_db'
  ```
- [ ] n8n container running
  ```bash
  ssh ubuntu@54.234.155.244 "docker ps | grep n8n"
  ```
- [ ] Sufficient disk space (need ~100MB)
  ```bash
  ssh ubuntu@54.234.155.244 "df -h /var/lib/docker"
  ```

### Backup & Safety
- [ ] Backup current workflow JSON
  ```bash
  scp ubuntu@54.234.155.244:/home/ubuntu/COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json \
      /Users/et/cyber-squire-ops/backups/workflow_supervisor_agent_$(date +%Y%m%d_%H%M%S).json
  ```
- [ ] Backup existing PostgreSQL data (if any)
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db pg_dump -U postgres cd_automation_db > /tmp/cd_automation_db_backup.sql'
  ```
- [ ] Document current n8n execution count (baseline)
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT COUNT(*) FROM telegram_message_log;"'
  ```

### Planning Review
- [ ] Read [README.md](./README.md) (overview)
- [ ] Read [QUICKSTART.md](./QUICKSTART.md) (deployment steps)
- [ ] Review [PLAN.md](./PLAN.md) (task breakdown)
- [ ] Skim [IMPLEMENTATION.md](./IMPLEMENTATION.md) (troubleshooting reference)

---

## Deployment Checklist

### Step 1: Deploy Database Schema
**Estimated Time**: 3 minutes

- [ ] Navigate to Phase 4 directory
  ```bash
  cd /Users/et/cyber-squire-ops/.planning/phases/04-memory-context
  ```
- [ ] Run deployment script
  ```bash
  ./deploy.sh
  ```
- [ ] Verify output shows:
  - [ ] ✓ Table created
  - [ ] ✓ Indexes created (3)
  - [ ] ✓ Auto-pruning trigger created
  - [ ] ✓ Functions created (3)
  - [ ] ✓ Statistics view created
- [ ] Record deployment timestamp:
  ```
  Deployed at: __________________
  ```

### Step 2: Verify Workflow Configuration
**Estimated Time**: 2 minutes

- [ ] Open n8n UI: http://54.234.155.244:5678
- [ ] Open workflow: "Telegram Supervisor Agent"
- [ ] Locate "Chat Memory" node
- [ ] Verify settings:
  - [ ] Session ID Type: `customKey`
  - [ ] Session Key: `={{ $json.chatId }}`
  - [ ] Table Name: `chat_memory`
  - [ ] Context Window Length: `13`
  - [ ] PostgreSQL Credentials: `cd-postgres-main`
- [ ] Verify connection (purple line):
  - [ ] Chat Memory → Supervisor Agent (ai_memory connection)
- [ ] Screenshot configuration for documentation: _______________

### Step 3: Run Automated Tests
**Estimated Time**: 5 minutes

- [ ] Run test suite
  ```bash
  ./test.sh
  ```
- [ ] Record test results:
  - [ ] Test 1: Schema Validation → ✅ PASS / ❌ FAIL
  - [ ] Test 2: Auto-Pruning → ✅ PASS / ❌ FAIL
  - [ ] Test 3: Context Window Function → ✅ PASS / ❌ FAIL
  - [ ] Test 4: Stale Session Cleanup → ✅ PASS / ❌ FAIL
  - [ ] Test 5: Query Performance → ✅ PASS / ❌ FAIL
  - [ ] Test 6: Telegram Integration → ✅ PASS / ⊘ SKIP / ❌ FAIL
- [ ] Overall pass rate: _____%
- [ ] If any test fails, check [IMPLEMENTATION.md](./IMPLEMENTATION.md) → Troubleshooting

---

## Validation Checklist

### Manual Test 1: Simple Task Reference (SC-4.1)
**Estimated Time**: 3 minutes

- [ ] Send Telegram message:
  ```
  I need to deploy the monitoring dashboard
  ```
- [ ] Verify bot response acknowledges request
- [ ] Send follow-up message:
  ```
  Add that task
  ```
- [ ] Expected: Bot creates task with "monitoring dashboard"
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] Notes: _______________________________________________

### Manual Test 2: Financial Reference (SC-4.1)
**Estimated Time**: 3 minutes

- [ ] Send Telegram message:
  ```
  I spent $150 on AWS this month
  ```
- [ ] Verify bot response
- [ ] Send follow-up message:
  ```
  Log that expense
  ```
- [ ] Expected: Bot logs $150 AWS expense
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] Notes: _______________________________________________

### Manual Test 3: Multi-Turn Conversation (SC-4.1)
**Estimated Time**: 5 minutes

- [ ] Send Telegram message:
  ```
  What's on my plate today?
  ```
- [ ] Verify bot returns task list
- [ ] Send follow-up message:
  ```
  How long will the first task take?
  ```
- [ ] Expected: Bot references specific task from previous message
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] Send third message:
  ```
  Schedule it for this afternoon
  ```
- [ ] Expected: Bot schedules the task from turn 1
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] Notes: _______________________________________________

### Manual Test 4: Restart Persistence (SC-4.3)
**Estimated Time**: 10 minutes

- [ ] Send Telegram message with unique identifier:
  ```
  Remember this task: Deploy Phase 4 at timestamp [CURRENT_TIMESTAMP]
  ```
- [ ] Record timestamp: _______________
- [ ] Verify message in database:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT content FROM chat_memory WHERE content LIKE '"'%Deploy Phase 4%'"' ORDER BY created_at DESC LIMIT 1;"'
  ```
- [ ] Restart n8n container:
  ```bash
  ssh ubuntu@54.234.155.244 'cd /home/ubuntu/COREDIRECTIVE_ENGINE && docker-compose restart n8n'
  ```
- [ ] Wait 30 seconds for n8n to be ready
- [ ] Send reference message:
  ```
  Add that task to my list
  ```
- [ ] Expected: Bot references "Deploy Phase 4" from before restart
- [ ] Result: ✅ PASS / ❌ FAIL
- [ ] Verify messages still in database:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT COUNT(*) FROM chat_memory WHERE content LIKE '"'%Deploy Phase 4%'"';"'
  ```
- [ ] Notes: _______________________________________________

---

## Success Criteria Validation

### SC-4.1: Contextual References Work
- [ ] Task reference test passed (Manual Test 1)
- [ ] Financial reference test passed (Manual Test 2)
- [ ] Multi-turn conversation test passed (Manual Test 3)
- [ ] Overall SC-4.1: ✅ SATISFIED / ❌ NOT SATISFIED

### SC-4.2: Context Window Shows 13-14 Messages
- [ ] Automated test passed (Test 3: Context Window Function)
- [ ] Manual verification:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT COUNT(*) FROM get_chat_context('"'YOUR_CHAT_ID'"');"'
  ```
- [ ] Result: _____ messages (should be ≤13)
- [ ] Overall SC-4.2: ✅ SATISFIED / ❌ NOT SATISFIED

### SC-4.3: Memory Persists Across Restarts
- [ ] Restart persistence test passed (Manual Test 4)
- [ ] Overall SC-4.3: ✅ SATISFIED / ❌ NOT SATISFIED

### SC-4.4: Old Messages Auto-Pruned
- [ ] Automated test passed (Test 2: Auto-Pruning)
- [ ] Manual verification (send 20 messages, check count):
  ```bash
  # Send 20 test messages via Telegram, then check:
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT COUNT(*) FROM chat_memory WHERE session_id = '"'YOUR_CHAT_ID'"';"'
  ```
- [ ] Result: _____ messages (should be ≤13)
- [ ] Overall SC-4.4: ✅ SATISFIED / ❌ NOT SATISFIED

---

## Performance Monitoring

### Baseline Metrics (Record Before Deployment)
- [ ] Average message processing latency: _____ ms
- [ ] PostgreSQL memory usage: _____ MB
- [ ] n8n execution count (last 24h): _____

### Post-Deployment Metrics (Record After 1 Hour)
- [ ] Average message processing latency: _____ ms
- [ ] PostgreSQL memory usage: _____ MB
- [ ] n8n execution count (last 1h): _____
- [ ] chat_memory table size:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT pg_size_pretty(pg_total_relation_size('"'chat_memory'"'));"'
  ```
- [ ] Result: _____ (expected: <100MB)

### Context Query Performance
- [ ] Run performance test:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "EXPLAIN ANALYZE SELECT * FROM chat_memory ORDER BY created_at DESC LIMIT 13;"'
  ```
- [ ] Execution time: _____ ms (target: <10ms)
- [ ] Result: ✅ PASS (<10ms) / ⚠️ WARN (10-50ms) / ❌ FAIL (>50ms)

---

## 24-Hour Stability Monitoring

### Hour 1
- [ ] Check n8n logs for errors:
  ```bash
  ssh ubuntu@54.234.155.244 'docker logs n8n --since 1h 2>&1 | grep -i "error\|memory"'
  ```
- [ ] Check PostgreSQL logs:
  ```bash
  ssh ubuntu@54.234.155.244 'docker logs cd-service-db --since 1h 2>&1 | grep -i "error\|memory"'
  ```
- [ ] Chat memory stats:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT * FROM chat_memory_stats;"'
  ```
- [ ] Issues found: _________________________________________

### Hour 6
- [ ] Repeat checks from Hour 1
- [ ] Message count per session (should be ≤13):
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT session_id, COUNT(*) FROM chat_memory GROUP BY session_id;"'
  ```
- [ ] Issues found: _________________________________________

### Hour 24
- [ ] Repeat checks from Hour 1
- [ ] Total messages in table:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT COUNT(*) FROM chat_memory;"'
  ```
- [ ] Table size:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT pg_size_pretty(pg_total_relation_size('"'chat_memory'"'));"'
  ```
- [ ] Index usage statistics:
  ```bash
  ssh ubuntu@54.234.155.244 'docker exec cd-service-db psql -U postgres -d cd_automation_db -c "SELECT indexname, idx_scan FROM pg_stat_user_indexes WHERE tablename = '"'chat_memory'"';"'
  ```
- [ ] Issues found: _________________________________________

---

## User Feedback Collection

### User Satisfaction Survey (After 1 Week)
Ask users:
- [ ] "Do conversations feel more natural?" (Y/N)
- [ ] "Do you have to repeat yourself less?" (Y/N)
- [ ] "Rate cognitive load: Lower / Same / Higher"
- [ ] "Any issues with context understanding?" (Free text)

### Usage Metrics (After 1 Week)
- [ ] Total conversations: _____
- [ ] Average messages per conversation: _____
- [ ] Context reference rate (% of convos with "that task" etc): _____%
- [ ] Re-clarification rate (% of convos where AI asks "which task?"): _____%

---

## Rollback Decision

### Rollback Triggers (Execute rollback if any of these occur)
- [ ] ❌ Critical: n8n crashes due to memory errors
- [ ] ❌ Critical: PostgreSQL database corruption
- [ ] ❌ Critical: >50% of context references fail
- [ ] ❌ Major: >100ms added latency per message
- [ ] ❌ Major: User complaints about incorrect context
- [ ] ⚠️ Minor: Context works but occasionally incorrect (tune, don't rollback)

### Rollback Procedure (If Triggered)
- [ ] Open n8n UI: http://54.234.155.244:5678
- [ ] Workflow: "Telegram Supervisor Agent"
- [ ] Disconnect Chat Memory node from Supervisor Agent
- [ ] Save workflow
- [ ] Verify workflow continues functioning (stateless mode)
- [ ] Document rollback reason: _____________________________
- [ ] Schedule post-mortem review

---

## Completion Checklist

### Phase 4 Complete When:
- [ ] All 4 success criteria satisfied (SC-4.1 through SC-4.4)
- [ ] All automated tests passing (6/6)
- [ ] All manual tests passing (4/4)
- [ ] 24-hour stability monitoring complete with no critical issues
- [ ] Performance metrics within targets (<10ms queries, <100MB table)
- [ ] User feedback collected and positive

### Documentation
- [ ] Update [SUMMARY.md](./SUMMARY.md) with final results
- [ ] Record deployment timestamp in this checklist
- [ ] Save completed checklist for audit trail
- [ ] Update main project README with Phase 4 completion status

### Handoff
- [ ] Brief next session maintainer on Phase 4 status
- [ ] Share location of monitoring queries
- [ ] Document any edge cases or quirks discovered
- [ ] Note any recommended future enhancements

---

## Sign-Off

**Deployment Completed By**: ____________________
**Date**: ____________________
**Time**: ____________________

**Success Criteria Met**: ✅ YES / ❌ NO (with exceptions noted)

**Overall Phase 4 Status**:
- [ ] ✅ COMPLETE (all criteria met, no issues)
- [ ] ⚠️ COMPLETE WITH NOTES (criteria met, minor issues documented)
- [ ] ❌ INCOMPLETE (rollback executed or criteria not met)

**Notes**:
_______________________________________________
_______________________________________________
_______________________________________________

---

**Phase 4: Memory & Context**
**Execution Checklist v1.0**
**Last Updated**: 2026-02-04
