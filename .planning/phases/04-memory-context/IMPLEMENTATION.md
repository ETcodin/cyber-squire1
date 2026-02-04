# Phase 4: Memory & Context - Implementation Guide

## Overview
This phase implements PostgreSQL-backed chat memory to enable the AI Supervisor Agent to maintain conversation context across messages. The implementation allows for contextual references like "add that task" where the AI correctly identifies the referenced entity from previous messages.

## Architecture

```
┌─────────────────┐
│ Telegram User   │
└────────┬────────┘
         │ Message
         ▼
┌─────────────────────────────────────┐
│ Telegram Supervisor Agent Workflow  │
│                                     │
│  ┌────────────┐    ┌─────────────┐ │
│  │ Parse Input│───▶│Chat Memory  │ │
│  └────────────┘    │   Node      │ │
│                    └──────┬──────┘ │
│                           │        │
│                           ▼        │
│  ┌──────────────────────────────┐ │
│  │   Supervisor Agent (Qwen)    │ │
│  │   - Tool Routing             │ │
│  │   - Context Awareness        │ │
│  └──────────────────────────────┘ │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│ PostgreSQL (cd-service-db)          │
│                                     │
│  ┌────────────────────────────────┐│
│  │ chat_memory table              ││
│  │ - session_id (Telegram chat_id)││
│  │ - role (user/assistant)        ││
│  │ - content (message text)       ││
│  │ - created_at (timestamp)       ││
│  │ - metadata (JSONB)             ││
│  └────────────────────────────────┘│
│                                     │
│  Auto-pruning trigger:              │
│  - Keeps last 13 messages per chat  │
│  - Runs after each insert           │
└─────────────────────────────────────┘
```

## Components

### 1. PostgreSQL Schema
**File**: `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/sql/chat_memory_13window.sql`

**Key Features**:
- **Table**: `chat_memory` - Stores all conversation messages
- **Indexes**: Optimized for session lookups and time-based queries
- **Trigger**: `trigger_prune_chat_memory` - Auto-deletes messages beyond 13-window
- **Functions**:
  - `prune_chat_memory_window()` - Pruning logic
  - `get_chat_context(session_id)` - Retrieve context for a session
  - `cleanup_stale_sessions()` - Weekly maintenance
- **View**: `chat_memory_stats` - Monitoring and statistics

### 2. n8n Chat Memory Node
**Workflow**: `workflow_supervisor_agent.json` (lines 112-129)

**Configuration**:
```json
{
  "parameters": {
    "sessionIdType": "customKey",
    "sessionKey": "={{ $json.chatId }}",
    "tableName": "chat_memory",
    "contextWindowLength": 13
  },
  "type": "@n8n/n8n-nodes-langchain.memoryPostgresChat",
  "credentials": {
    "postgres": {
      "id": "cd-postgres-main",
      "name": "CD PostgreSQL"
    }
  }
}
```

**How It Works**:
1. **Session Isolation**: Each Telegram chat has a unique `chatId` used as session_id
2. **Context Injection**: Before each AI request, last 13 messages are loaded
3. **Message Storage**: After AI response, both user message and AI response are stored
4. **Auto-Pruning**: Trigger automatically maintains 13-message window

### 3. AI Agent Integration
**Node**: "Supervisor Agent" (lines 131-141)

The Chat Memory node connects via the `ai_memory` connection type (line 303-304), providing the AI with conversation history in its prompt context.

**Prompt Enhancement**:
```
System: You are CYBER-SQUIRE...

[Previous conversation context - last 13 messages]
User: I need to deploy the monitoring dashboard
Assistant: I'll help you with that. Would you like me to add it to your task list?
User: Yes, add that task
[Current user message is appended here]
```

The AI can now reference "that task" because it sees "monitoring dashboard" in the context.

## Implementation Steps

### Step 1: Deploy Database Schema
```bash
cd /Users/et/cyber-squire-ops/.planning/phases/04-memory-context
./deploy.sh
```

**What This Does**:
1. Connects to EC2 instance
2. Verifies PostgreSQL is running
3. Deploys chat_memory schema (if not exists)
4. Validates table, indexes, triggers, and functions
5. Runs auto-pruning test
6. Shows current memory stats

**Expected Output**:
```
[INFO] Running pre-flight checks...
[INFO] Pre-flight checks passed
[INFO] Checking PostgreSQL status...
[INFO] PostgreSQL container is running
[INFO] Checking if chat_memory table exists...
[INFO] Deploying chat_memory schema...
[INFO] Schema deployed successfully
[INFO] Validating deployment...
[INFO] ✓ Table created
[INFO] ✓ Indexes created (3)
[INFO] ✓ Auto-pruning trigger created
[INFO] ✓ Functions created (3)
[INFO] ✓ Statistics view created
[INFO] All validation checks passed
```

### Step 2: Verify Workflow Configuration
**Manual Check in n8n UI**:

1. Open n8n: `http://54.234.155.244:5678`
2. Open workflow: "Telegram Supervisor Agent"
3. Verify "Chat Memory" node settings:
   - Session ID Type: `customKey`
   - Session Key: `={{ $json.chatId }}`
   - Table Name: `chat_memory`
   - Context Window Length: `13`
   - Credentials: `cd-postgres-main`
4. Verify connection: Chat Memory → Supervisor Agent (purple line)

**The workflow JSON already has this configuration** (lines 112-129), so this is just verification.

### Step 3: Run Test Suite
```bash
cd /Users/et/cyber-squire-ops/.planning/phases/04-memory-context

# Set Telegram credentials (optional, for integration tests)
export TELEGRAM_BOT_TOKEN="your_bot_token"
export TELEGRAM_CHAT_ID="your_chat_id"

# Run tests
./test.sh
```

**Tests Executed**:
1. Schema validation (table, indexes, triggers, functions)
2. Auto-pruning mechanism (insert 20, verify 13 remain)
3. Context window function (get_chat_context returns 13)
4. Stale session cleanup (delete 8-day-old sessions)
5. Query performance (< 10ms for context retrieval)
6. Telegram integration (if credentials set)

**Expected Output**:
```
============================================
Test Report: Phase 4 - Memory & Context
============================================

Tests Passed:  6
Tests Failed:  0
Tests Skipped: 0

Pass Rate: 100%

All tests passed!

Success Criteria Status:
  ✓ SC-4.1: Contextual references (manual validation required)
  ✓ SC-4.2: 13-message context window (Test 3)
  ✓ SC-4.3: Memory persistence (Test 1)
  ✓ SC-4.4: Auto-pruning (Test 2)
```

### Step 4: Manual Validation (SC-4.1)
Test contextual reference resolution via Telegram:

**Test Case 1: Task Reference**
```
You: I need to deploy the monitoring dashboard
Bot: I can help you with that. Would you like me to add it to your task list using the ADHD Commander?
You: Yes, add that task
Bot: [Calls ADHD_Commander with "deploy monitoring dashboard"]
```

**Test Case 2: Financial Reference**
```
You: I spent $150 on AWS this month
Bot: Got it. Would you like me to log that expense?
You: Log it
Bot: [Calls Finance_Manager with $150 and AWS category]
```

**Test Case 3: Multi-turn Conversation**
```
You: What's on my plate today?
Bot: [Returns task list via ADHD_Commander]
You: How long will the first task take?
Bot: Based on the task "Deploy Phase 4" from your list, I estimate...
You: Schedule it for this afternoon
Bot: [References "Deploy Phase 4" from earlier context]
```

### Step 5: Monitor Performance
```bash
# SSH to EC2
ssh -i ~/.ssh/cyber-squire-ops.pem ubuntu@54.234.155.244

# Check memory stats
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT * FROM chat_memory_stats;
"

# Monitor table size
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT
  pg_size_pretty(pg_total_relation_size('chat_memory')) AS total_size,
  pg_size_pretty(pg_relation_size('chat_memory')) AS table_size,
  pg_size_pretty(pg_total_relation_size('chat_memory') - pg_relation_size('chat_memory')) AS index_size;
"

# Watch n8n logs for memory operations
docker logs -f n8n 2>&1 | grep -i "memory\|chat_memory"
```

## Configuration Reference

### Context Window Size
**Current**: 13 messages
**Location**: `workflow_supervisor_agent.json`, line 116

To adjust:
1. Edit workflow in n8n UI
2. Change "Context Window Length" in Chat Memory node
3. Optionally update trigger in SQL to match:
```sql
-- Update pruning offset
OFFSET 13  -- Change to desired window size
```

### Session Isolation
**Current**: `chatId` (Telegram chat ID)
**Location**: `workflow_supervisor_agent.json`, line 114

This ensures:
- Each Telegram chat has its own memory
- Group chats vs. private chats are isolated
- Multiple users don't share context

### Stale Session Cleanup
**Current**: 7 days of inactivity
**Location**: `chat_memory_13window.sql`, line 72

To adjust:
```sql
HAVING MAX(created_at) < NOW() - INTERVAL '7 days'  -- Change interval
```

To enable automatic cleanup (weekly):
```sql
-- Requires pg_cron extension
SELECT cron.schedule(
  'cleanup-stale-sessions',
  '0 2 * * 0',  -- 2 AM every Sunday
  $$ SELECT cleanup_stale_sessions(); $$
);
```

## Troubleshooting

### Issue: Context Not Working (AI doesn't remember)
**Symptoms**: AI responds as if it's a new conversation every time

**Diagnosis**:
```bash
# Check if messages are being stored
ssh -i ~/.ssh/cyber-squire-ops.pem ubuntu@54.234.155.244
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT session_id, COUNT(*) FROM chat_memory GROUP BY session_id;
"
```

**Solutions**:
1. **No messages in database**: Chat Memory node is not connected
   - Verify connection in n8n UI (purple line from Chat Memory to Supervisor Agent)
   - Check credentials are valid (cd-postgres-main)

2. **Messages stored but not used**: Context window too small
   - Increase context window length in Chat Memory node

3. **Wrong session_id**: Session isolation issue
   - Verify sessionKey is `={{ $json.chatId }}`
   - Check Parse Input node outputs correct chatId

### Issue: Auto-Pruning Not Working
**Symptoms**: Table grows unbounded, more than 13 messages per session

**Diagnosis**:
```bash
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT session_id, COUNT(*) AS count
FROM chat_memory
GROUP BY session_id
HAVING COUNT(*) > 13;
"
```

**Solutions**:
1. **Trigger not installed**:
```bash
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT tgname FROM pg_trigger WHERE tgrelid = 'chat_memory'::regclass;
"
```
Re-run `deploy.sh` if trigger is missing.

2. **Trigger disabled**:
```sql
ALTER TABLE chat_memory ENABLE TRIGGER trigger_prune_chat_memory;
```

### Issue: Slow Performance
**Symptoms**: High latency when sending messages

**Diagnosis**:
```bash
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
EXPLAIN ANALYZE
SELECT * FROM chat_memory
WHERE session_id = 'test-session'
ORDER BY created_at DESC
LIMIT 13;
"
```

**Solutions**:
1. **Missing indexes**: Re-run `deploy.sh`
2. **Table too large**: Run cleanup_stale_sessions()
3. **Database overloaded**: Check PostgreSQL resource usage

### Issue: Memory Doesn't Persist After Restart
**Symptoms**: Context lost after n8n restart

**Diagnosis**:
```bash
# Before restart
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT COUNT(*) FROM chat_memory WHERE session_id = 'YOUR_CHAT_ID';
"

# Restart n8n
cd /home/ubuntu/COREDIRECTIVE_ENGINE
docker-compose restart n8n

# After restart
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT COUNT(*) FROM chat_memory WHERE session_id = 'YOUR_CHAT_ID';
"
```

**Solution**: This should not happen - PostgreSQL data is persisted in Docker volumes. If data is lost, check:
```bash
docker volume ls | grep postgres
docker inspect cd-service-db | grep Mounts -A 10
```

## Monitoring & Maintenance

### Daily Checks
```bash
# Check active sessions
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT * FROM chat_memory_stats ORDER BY last_message DESC LIMIT 10;
"

# Check table size
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT pg_size_pretty(pg_total_relation_size('chat_memory'));
"
```

### Weekly Maintenance
```bash
# Clean up stale sessions (7+ days inactive)
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT cleanup_stale_sessions();
"
```

### Performance Metrics
```bash
# Index usage statistics
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT
  schemaname, tablename, indexname,
  idx_scan AS scans,
  idx_tup_read AS tuples_read,
  idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE tablename = 'chat_memory';
"
```

## Success Criteria Validation

### SC-4.1: Contextual References Work
**How to Test**: Send "I need to deploy X" → "Add that task"
**Expected**: AI correctly identifies X as the referenced task
**Validation**: Manual testing via Telegram (see Step 4 above)

### SC-4.2: Context Window Shows 13-14 Messages
**How to Test**: Insert 20 messages, query context function
**Expected**: Only last 13 messages returned
**Validation**: Automated in `test.sh` (Test 3)

### SC-4.3: Memory Persists Across Restarts
**How to Test**: Send message → restart n8n → reference previous message
**Expected**: AI has access to pre-restart context
**Validation**: See TESTING.md, Test 5

### SC-4.4: Old Messages Auto-Pruned
**How to Test**: Insert 20 messages, check table
**Expected**: Only 13 messages remain
**Validation**: Automated in `test.sh` (Test 2)

## Rollback Plan

If memory implementation causes critical issues:

1. **Disable Chat Memory in Workflow**:
   - Open n8n UI
   - Disconnect Chat Memory node from Supervisor Agent
   - Save workflow
   - Workflow continues in stateless mode

2. **Or: Revert to Previous Workflow Version** (if backed up):
```bash
scp backup_workflow_supervisor_agent.json ubuntu@54.234.155.244:/tmp/
# Import via n8n UI
```

3. **Nuclear Option: Drop Table**:
```bash
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
DROP TABLE IF EXISTS chat_memory CASCADE;
"
```

## Next Steps

After validating Phase 4:
1. Monitor for 24 hours in production
2. Collect usage statistics from `chat_memory_stats`
3. Review routing_decision logs for context-aware tool calls
4. Consider tuning context window based on actual conversation patterns
5. Document any edge cases discovered
6. Proceed to Phase 5 (if applicable)

## References
- **Workflow JSON**: `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json`
- **SQL Schema**: `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/sql/chat_memory_13window.sql`
- **Test Suite**: `/Users/et/cyber-squire-ops/.planning/phases/04-memory-context/test.sh`
- **Deployment Script**: `/Users/et/cyber-squire-ops/.planning/phases/04-memory-context/deploy.sh`
- **n8n LangChain Docs**: https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/
