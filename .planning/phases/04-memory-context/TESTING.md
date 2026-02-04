# Phase 4: Memory & Context - Testing Guide

## Test Environment
- **EC2**: 54.234.155.244
- **Database**: cd-service-db/cd_automation_db
- **Workflow**: workflow_supervisor_agent.json
- **Telegram Bot**: @CyberSquireBot (configured in n8n)

## Prerequisites
```bash
# Set environment variables
export EC2_HOST="54.234.155.244"
export BOT_TOKEN="<your_telegram_bot_token>"
export CHAT_ID="<your_telegram_chat_id>"
export SSH_KEY="/path/to/cyber-squire-ops.pem"
```

## Test Suite

---

## Test 1: Schema Validation
**Success Criteria**: SC-4.3 (Memory persists), SC-4.4 (Auto-pruning)
**Duration**: 5 minutes

### 1.1 Verify Database Schema
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
-- Check table exists
SELECT
  table_name,
  pg_size_pretty(pg_total_relation_size(table_name::regclass)) AS size
FROM information_schema.tables
WHERE table_name = 'chat_memory';
"
EOF
```

**Expected Output**:
```
 table_name  |  size
-------------+--------
 chat_memory | 16 kB
```

### 1.2 Verify Indexes
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'chat_memory';
"
EOF
```

**Expected Output**:
```
           indexname            |                           indexdef
--------------------------------+--------------------------------------------------------------
 chat_memory_pkey               | CREATE UNIQUE INDEX chat_memory_pkey ON ...
 idx_chat_memory_session_id     | CREATE INDEX idx_chat_memory_session_id ON ...
 idx_chat_memory_session_created| CREATE INDEX idx_chat_memory_session_created ON ...
```

### 1.3 Verify Trigger and Functions
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
-- Check trigger
SELECT tgname, proname
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'chat_memory'::regclass;

-- Check functions exist
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name IN ('prune_chat_memory_window', 'get_chat_context', 'cleanup_stale_sessions');
"
EOF
```

**Expected Output**:
```
           tgname              |       proname
-------------------------------+-----------------------
 trigger_prune_chat_memory     | prune_chat_memory_window

     routine_name          | routine_type
---------------------------+--------------
 prune_chat_memory_window  | FUNCTION
 get_chat_context          | FUNCTION
 cleanup_stale_sessions    | FUNCTION
```

**Status**: ✅ PASS / ❌ FAIL

---

## Test 2: Auto-Pruning Validation
**Success Criteria**: SC-4.4 (Old messages automatically pruned)
**Duration**: 5 minutes

### 2.1 Insert 20 Test Messages
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
-- Create test session
DELETE FROM chat_memory WHERE session_id = 'test-pruning-session';

-- Insert 20 messages
INSERT INTO chat_memory (session_id, role, content)
SELECT
  'test-pruning-session',
  CASE WHEN n % 2 = 0 THEN 'user' ELSE 'assistant' END,
  'Test message number ' || n
FROM generate_series(1, 20) AS n;

-- Count messages (should be 13 due to auto-pruning)
SELECT COUNT(*) AS message_count
FROM chat_memory
WHERE session_id = 'test-pruning-session';
"
EOF
```

**Expected Output**:
```
 message_count
---------------
            13
```

### 2.2 Verify Oldest Messages Were Pruned
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
-- Get remaining messages (should be 8-20, not 1-7)
SELECT content
FROM chat_memory
WHERE session_id = 'test-pruning-session'
ORDER BY created_at ASC;
"
EOF
```

**Expected Output**: Should show "Test message number 8" through "20" (13 messages total)

### 2.3 Cleanup Test Session
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
DELETE FROM chat_memory WHERE session_id = 'test-pruning-session';
"
EOF
```

**Status**: ✅ PASS / ❌ FAIL

---

## Test 3: Context Window Functionality
**Success Criteria**: SC-4.2 (Context window shows last 13-14 messages)
**Duration**: 10 minutes

### 3.1 Send Sequential Messages via Telegram
```bash
# Send 15 messages
for i in {1..15}; do
  echo "Sending message $i..."
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="Test context message $i" > /dev/null
  sleep 3
done
```

### 3.2 Verify Message Count in Database
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << EOF
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT COUNT(*) AS message_count
FROM chat_memory
WHERE session_id = '${CHAT_ID}';
"
EOF
```

**Expected Output**: Should show 13 or fewer messages (depending on assistant responses)

### 3.3 Test Context Retrieval Function
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << EOF
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT role, SUBSTRING(content, 1, 50) AS content_preview, created_at
FROM get_chat_context('${CHAT_ID}');
"
EOF
```

**Expected Output**: Should return last 13 messages in chronological order

**Status**: ✅ PASS / ❌ FAIL

---

## Test 4: Contextual Reference Resolution
**Success Criteria**: SC-4.1 ("Add that task" correctly identifies the task)
**Duration**: 15 minutes

### 4.1 Task Reference Test
```bash
# Message 1: Establish context
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="I need to deploy the monitoring dashboard this week"

sleep 5

# Message 2: Reference previous context
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="Add that task to my Notion board"

# Wait for response
sleep 10
```

**Manual Validation**:
1. Check Telegram for AI response
2. AI should reference "monitoring dashboard"
3. AI should call ADHD_Commander tool

**Check Routing Logs**:
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker logs n8n 2>&1 | grep -A 5 "ROUTING_DECISION" | tail -20
EOF
```

**Expected Output**: Should show `tools_called: ["ADHD_Commander"]`

**Status**: ✅ PASS / ❌ FAIL

---

### 4.2 Financial Reference Test
```bash
# Message 1: Financial context
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="I spent $150 on AWS this month"

sleep 5

# Message 2: Reference previous amount
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="Log that expense"

sleep 10
```

**Manual Validation**:
1. AI should reference "$150" and "AWS"
2. AI should call Finance_Manager tool

**Status**: ✅ PASS / ❌ FAIL

---

### 4.3 Multi-Turn Conversation Test
```bash
# Turn 1: Ask for tasks
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="What's on my plate today?"

sleep 10

# Turn 2: Ask about first task
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="How long will the first task take?"

sleep 10

# Turn 3: Reference task from turn 1
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="Schedule it for this afternoon"

sleep 10
```

**Manual Validation**:
1. AI maintains context across 3 turns
2. "it" in turn 3 correctly references task from turn 1
3. AI provides coherent response

**Status**: ✅ PASS / ❌ FAIL

---

## Test 5: Memory Persistence Across Restarts
**Success Criteria**: SC-4.3 (Memory persists across n8n restarts)
**Duration**: 10 minutes

### 5.1 Send Pre-Restart Message
```bash
# Send message with unique identifier
TIMESTAMP=$(date +%s)
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="Remember this task: Deploy Phase 4 at timestamp $TIMESTAMP"

sleep 5

# Verify message in database
ssh -i $SSH_KEY ubuntu@$EC2_HOST << EOF
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT content
FROM chat_memory
WHERE session_id = '${CHAT_ID}'
  AND content LIKE '%Deploy Phase 4%'
ORDER BY created_at DESC
LIMIT 1;
"
EOF
```

**Expected Output**: Should show the message with timestamp

### 5.2 Restart n8n Container
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
cd /home/ubuntu/COREDIRECTIVE_ENGINE
docker-compose restart n8n
EOF

# Wait for n8n to be ready
echo "Waiting 30 seconds for n8n to restart..."
sleep 30
```

### 5.3 Verify n8n is Running
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker ps | grep n8n
EOF
```

**Expected Output**: Should show n8n container running

### 5.4 Send Post-Restart Reference Message
```bash
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="Add that task to my list"

sleep 10
```

### 5.5 Verify Context Was Preserved
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << EOF
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT role, SUBSTRING(content, 1, 80) AS content
FROM chat_memory
WHERE session_id = '${CHAT_ID}'
ORDER BY created_at DESC
LIMIT 5;
"
EOF
```

**Expected Output**: Should show both pre-restart and post-restart messages

**Manual Validation**:
- AI response references "Deploy Phase 4"
- No errors in n8n logs

**Status**: ✅ PASS / ❌ FAIL

---

## Test 6: Performance & Monitoring
**Success Criteria**: Memory operations have negligible latency
**Duration**: 5 minutes

### 6.1 Query Performance Test
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << EOF
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
EXPLAIN ANALYZE
SELECT * FROM chat_memory
WHERE session_id = '${CHAT_ID}'
ORDER BY created_at DESC
LIMIT 13;
"
EOF
```

**Expected Output**: Execution time < 10ms

### 6.2 Check Memory Statistics
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT * FROM chat_memory_stats;
"
EOF
```

**Expected Output**: Stats for all active sessions

### 6.3 Check Table Size
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT
  pg_size_pretty(pg_total_relation_size('chat_memory')) AS total_size,
  pg_size_pretty(pg_relation_size('chat_memory')) AS table_size,
  pg_size_pretty(pg_total_relation_size('chat_memory') - pg_relation_size('chat_memory')) AS index_size;
"
EOF
```

**Expected Output**: Table size < 100MB for normal usage

**Status**: ✅ PASS / ❌ FAIL

---

## Test 7: Stale Session Cleanup
**Success Criteria**: Old sessions are automatically cleaned
**Duration**: 5 minutes

### 7.1 Create Stale Session
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
-- Insert old messages
INSERT INTO chat_memory (session_id, role, content, created_at)
SELECT
  'stale-session-' || n,
  'user',
  'Old message',
  NOW() - INTERVAL '8 days'
FROM generate_series(1, 5) AS n;

-- Verify they exist
SELECT COUNT(*) AS stale_count
FROM chat_memory
WHERE session_id LIKE 'stale-session-%';
"
EOF
```

**Expected Output**: Should show 5 stale messages

### 7.2 Run Cleanup Function
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT cleanup_stale_sessions() AS deleted_count;
"
EOF
```

**Expected Output**: Should return deleted_count = 5

### 7.3 Verify Deletion
```bash
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT COUNT(*) AS remaining_stale
FROM chat_memory
WHERE session_id LIKE 'stale-session-%';
"
EOF
```

**Expected Output**: Should return 0

**Status**: ✅ PASS / ❌ FAIL

---

## Test Summary Report

### Test Results
| Test ID | Test Name | Success Criteria | Status | Duration |
|---------|-----------|------------------|--------|----------|
| Test 1 | Schema Validation | SC-4.3, SC-4.4 | ⬜ | 5 min |
| Test 2 | Auto-Pruning | SC-4.4 | ⬜ | 5 min |
| Test 3 | Context Window | SC-4.2 | ⬜ | 10 min |
| Test 4.1 | Task Reference | SC-4.1 | ⬜ | 5 min |
| Test 4.2 | Financial Reference | SC-4.1 | ⬜ | 5 min |
| Test 4.3 | Multi-Turn | SC-4.1 | ⬜ | 5 min |
| Test 5 | Restart Persistence | SC-4.3 | ⬜ | 10 min |
| Test 6 | Performance | N/A | ⬜ | 5 min |
| Test 7 | Stale Cleanup | SC-4.4 | ⬜ | 5 min |

### Success Criteria Coverage
- ✅ SC-4.1: Contextual references (Test 4.1, 4.2, 4.3)
- ✅ SC-4.2: 13-message window (Test 3)
- ✅ SC-4.3: Restart persistence (Test 1, Test 5)
- ✅ SC-4.4: Auto-pruning (Test 2, Test 7)

### Known Issues
*(Document any issues found during testing)*

### Recommendations
*(Document any improvements or optimizations)*

## Rollback Procedure
If critical issues are found:

```bash
# 1. Disable Chat Memory node in workflow
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
# Edit workflow JSON to disconnect memory node
# This requires manual UI intervention or JSON editing
EOF

# 2. Restart n8n to apply changes
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
cd /home/ubuntu/COREDIRECTIVE_ENGINE
docker-compose restart n8n
EOF

# 3. Optionally drop chat_memory table
ssh -i $SSH_KEY ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
DROP TABLE IF EXISTS chat_memory CASCADE;
"
EOF
```

## Notes
- All tests assume Telegram bot is properly configured
- Database schema must be deployed before running tests
- Some tests require manual validation via Telegram UI
- Performance benchmarks may vary with system load
