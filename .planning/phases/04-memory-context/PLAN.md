# Phase 4: Memory & Context - Implementation Plan

## Objective
Implement PostgreSQL-backed chat memory to maintain conversation context across messages, enabling the AI to reference prior messages and maintain continuity.

## Success Criteria
- **SC-4.1**: "Add that task" (referencing prior message) correctly identifies the task
- **SC-4.2**: Context window shows last 13-14 messages in AI prompt
- **SC-4.3**: Memory persists across n8n restarts
- **SC-4.4**: Old messages automatically pruned beyond window

## Infrastructure Context
- **EC2 Instance**: 54.234.155.244
- **PostgreSQL**: cd-service-db container, database: cd_automation_db
- **Workflow**: workflow_supervisor_agent.json
- **Memory Node**: Already configured at lines 112-129

## Current State Analysis

### Existing Implementation
The workflow already has:
1. ✅ PostgreSQL Chat Memory node (lines 112-129)
2. ✅ Session ID keyed to chatId (Telegram chat ID)
3. ✅ Context window set to 13 messages
4. ✅ Connected to cd-postgres-main credentials
5. ✅ Chat memory table schema exists (chat_memory_13window.sql)

### Schema Features (Already Implemented)
- Auto-pruning trigger: Deletes messages beyond 13-window after each insert
- Indexes for fast session lookups
- get_chat_context() function for retrieving context
- cleanup_stale_sessions() for weekly maintenance
- chat_memory_stats view for monitoring

## Implementation Tasks

### Task 1: Verify Database Schema Deployment
**Priority**: CRITICAL
**Status**: Pending
**Estimate**: 15 minutes

**Action Items**:
1. SSH to EC2 instance
2. Connect to PostgreSQL container
3. Verify chat_memory table exists
4. Verify trigger and functions are installed
5. Test auto-pruning with sample inserts

**Validation**:
```sql
-- Check table exists
\dt chat_memory

-- Check trigger exists
\d+ chat_memory

-- Check functions exist
\df prune_chat_memory_window
\df get_chat_context

-- Test auto-pruning
INSERT INTO chat_memory (session_id, role, content)
VALUES ('test-session', 'user', 'Test message ' || generate_series(1, 20));
SELECT COUNT(*) FROM chat_memory WHERE session_id = 'test-session';
-- Should return 13, not 20
```

**Expected Outcome**: All schema objects exist and pruning works

---

### Task 2: Test Memory Persistence Across Restarts
**Priority**: HIGH
**Status**: Pending
**Estimate**: 10 minutes
**Depends On**: Task 1

**Action Items**:
1. Send test message via Telegram
2. Verify message stored in chat_memory table
3. Restart n8n container: `docker-compose restart n8n`
4. Send follow-up message referencing first message
5. Check AI response includes context from previous message

**Test Script**:
```bash
# Message 1
curl -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
  -d chat_id=${CHAT_ID} \
  -d text="Remember this task: Deploy Phase 4"

# Restart n8n
ssh ubuntu@54.234.155.244 "cd /home/ubuntu/COREDIRECTIVE_ENGINE && docker-compose restart n8n"

# Wait 30 seconds
sleep 30

# Message 2 (references previous)
curl -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
  -d chat_id=${CHAT_ID} \
  -d text="Add that task to my list"
```

**Validation**:
- Query database: `SELECT * FROM chat_memory WHERE session_id = '<CHAT_ID>' ORDER BY created_at;`
- Should show both messages persisted
- AI response should reference "Deploy Phase 4"

**Expected Outcome**: SC-4.3 satisfied (memory persists across restarts)

---

### Task 3: Validate Context Window Size
**Priority**: HIGH
**Status**: Pending
**Estimate**: 15 minutes
**Depends On**: Task 1

**Action Items**:
1. Send 20 sequential messages via Telegram
2. Query chat_memory table to verify only 13 messages retained
3. Send 21st message asking "What was my first message?"
4. Verify AI response indicates early messages are not in context

**Test Script**:
```bash
# Send 20 messages
for i in {1..20}; do
  curl -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
    -d chat_id=${CHAT_ID} \
    -d text="Message number $i"
  sleep 2
done

# Verify pruning in database
psql -U postgres -d cd_automation_db -c \
  "SELECT COUNT(*) FROM chat_memory WHERE session_id = '<CHAT_ID>';"

# Ask about first message (should be pruned)
curl -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
  -d chat_id=${CHAT_ID} \
  -d text="What was message number 1?"
```

**Validation**:
- Database should show exactly 13 messages
- AI should respond that message 1 is not in context
- Messages 8-20 should be retrievable

**Expected Outcome**: SC-4.4 satisfied (auto-pruning works)

---

### Task 4: Test Contextual Reference Resolution
**Priority**: CRITICAL
**Status**: Pending
**Estimate**: 20 minutes
**Depends On**: Task 1, Task 2

**Action Items**:
1. Send message mentioning a specific task
2. Send follow-up using "that task" reference
3. Verify AI correctly identifies the referenced task
4. Test with multiple entities (tasks, amounts, systems)

**Test Cases**:

**Test Case 4.1: Task Reference**
```
Message 1: "I need to deploy the monitoring dashboard"
Message 2: "Add that task to my Notion board"
Expected: AI calls ADHD_Commander tool with "deploy monitoring dashboard"
```

**Test Case 4.2: Financial Reference**
```
Message 1: "I spent $150 on AWS this month"
Message 2: "Log that expense"
Expected: AI calls Finance_Manager with $150 and AWS category
```

**Test Case 4.3: System Reference**
```
Message 1: "The EC2 instance seems slow"
Message 2: "Check its status"
Expected: AI calls System_Status tool
```

**Test Case 4.4: Multi-turn Conversation**
```
Message 1: "What's on my plate today?"
Message 2: "How long will the first task take?"
Message 3: "Schedule it for this afternoon"
Expected: AI maintains context of the task across 3 turns
```

**Validation**:
- Check routing_decision logs for correct tool calls
- Verify chat_memory contains all messages
- AI responses reference previous context

**Expected Outcome**: SC-4.1 satisfied (contextual references work)

---

### Task 5: Monitor Memory Performance
**Priority**: MEDIUM
**Status**: Pending
**Estimate**: 10 minutes
**Depends On**: Task 1

**Action Items**:
1. Query chat_memory_stats view
2. Check table size: `SELECT pg_size_pretty(pg_total_relation_size('chat_memory'));`
3. Monitor index usage: `SELECT * FROM pg_stat_user_indexes WHERE relname = 'chat_memory';`
4. Verify query performance with EXPLAIN ANALYZE

**Monitoring Queries**:
```sql
-- Session statistics
SELECT * FROM chat_memory_stats;

-- Table size
SELECT pg_size_pretty(pg_total_relation_size('chat_memory')) AS total_size;

-- Index usage
SELECT
  schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename = 'chat_memory';

-- Query performance
EXPLAIN ANALYZE
SELECT * FROM chat_memory
WHERE session_id = 'test-session'
ORDER BY created_at DESC
LIMIT 13;
```

**Performance Targets**:
- Context window query: < 10ms
- Insert + pruning: < 50ms
- Table size: < 100MB for 1000 sessions

**Expected Outcome**: Memory operations have negligible latency impact

---

### Task 6: Test Stale Session Cleanup
**Priority**: LOW
**Status**: Pending
**Estimate**: 5 minutes
**Depends On**: Task 1

**Action Items**:
1. Insert test messages with old timestamps
2. Run cleanup_stale_sessions() function
3. Verify old sessions are deleted
4. Configure weekly cron job (optional)

**Test Script**:
```sql
-- Create stale session (8 days old)
INSERT INTO chat_memory (session_id, role, content, created_at)
VALUES ('stale-session', 'user', 'Old message', NOW() - INTERVAL '8 days');

-- Run cleanup
SELECT cleanup_stale_sessions();

-- Verify deletion
SELECT COUNT(*) FROM chat_memory WHERE session_id = 'stale-session';
-- Should return 0
```

**Optional: Configure Cron Job**:
```sql
-- Requires pg_cron extension
SELECT cron.schedule(
  'cleanup-stale-sessions',
  '0 2 * * 0',  -- 2 AM every Sunday
  $$ SELECT cleanup_stale_sessions(); $$
);
```

**Expected Outcome**: Old sessions are automatically cleaned up

---

## Testing Strategy

### Unit Tests
Each task has inline validation queries/scripts

### Integration Tests
- End-to-end conversation flow with context
- Multi-session isolation (separate Telegram chats)
- Restart resilience test

### Performance Tests
- Context retrieval latency under load
- Auto-pruning overhead measurement
- Table growth monitoring

## Rollback Plan
If memory implementation causes issues:
1. Disable Chat Memory node in workflow (disconnect from Supervisor Agent)
2. Workflow continues functioning without context (stateless mode)
3. Investigate issues without user impact
4. Re-enable after fixes

**Rollback Command**:
```bash
# Edit workflow JSON, remove memory connection at lines 303-304
# Redeploy workflow via n8n UI
```

## Deployment Checklist

### Pre-Deployment
- [ ] Verify PostgreSQL container is running
- [ ] Confirm cd_automation_db database exists
- [ ] Check available disk space (need ~100MB)
- [ ] Backup current workflow JSON

### Deployment
- [ ] Deploy chat_memory schema (if not exists)
- [ ] Verify workflow has Chat Memory node configured
- [ ] Test with single message
- [ ] Test with context reference
- [ ] Test with 20+ messages (pruning)

### Post-Deployment
- [ ] Monitor n8n execution logs
- [ ] Check PostgreSQL slow query log
- [ ] Verify memory stats view
- [ ] Document any issues

## Success Metrics

### Functional Metrics
- ✅ SC-4.1: Context references work (Test Case 4.1-4.4 pass)
- ✅ SC-4.2: Context window shows 13 messages (Task 3)
- ✅ SC-4.3: Memory survives restarts (Task 2)
- ✅ SC-4.4: Auto-pruning works (Task 3)

### Performance Metrics
- Context retrieval: < 10ms (99th percentile)
- Insert latency: < 50ms including pruning
- Table size growth: Linear with active sessions

### Reliability Metrics
- Memory availability: 99.9%
- Data consistency: No lost messages
- Pruning accuracy: Exactly 13 messages per session

## Dependencies
- PostgreSQL 16 running in cd-service-db container
- n8n with LangChain nodes installed
- workflow_supervisor_agent.json deployed
- cd-postgres-main credentials configured

## Timeline
- **Total Estimate**: 1.5 hours
- **Critical Path**: Task 1 → Task 2 → Task 4
- **Parallel Work**: Task 3, Task 5, Task 6 can run independently

## Next Steps After Phase 4
Once memory is validated:
1. Monitor for 24 hours in production
2. Collect usage statistics from chat_memory_stats
3. Consider tuning window size based on actual usage
4. Implement Phase 5 (if applicable)

## Notes
- Memory node is already configured in workflow (lines 112-129)
- Schema already exists (chat_memory_13window.sql)
- Main work is **validation and testing**, not implementation
- Focus on proving SC-4.1 through SC-4.4 work correctly
