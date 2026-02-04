# Phase 5: Fallback & Resilience - Testing Guide

## Test Environment Setup

### Prerequisites
- n8n workflow deployed with fallback logic
- PostgreSQL with `ai_failures` table created
- Gemini API key configured in `.env`
- Ollama service running on EC2
- Telegram bot active and responding

### Test Data Preparation

```sql
-- Clear previous test data
TRUNCATE TABLE ai_failures CASCADE;

-- Verify clean state
SELECT COUNT(*) FROM ai_failures;
-- Expected: 0
```

## Test Suite

### TC-5.1: Ollama Timeout Detection & Gemini Fallback

**Objective:** Verify that Ollama failure triggers Gemini fallback automatically

**Prerequisites:**
- Ollama service must be stoppable
- Gemini API key valid

**Procedure:**

1. **Baseline Test (Ollama Healthy)**
   ```bash
   # Verify Ollama is running
   ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244
   docker ps | grep ollama
   # Expected: ollama container running

   # Test Ollama directly
   curl http://localhost:11434/api/generate -d '{
     "model": "qwen2.5:7b",
     "prompt": "Hello",
     "stream": false
   }' | jq '.response'
   # Expected: Valid response within 5-10s
   ```

2. **Send Baseline Message**
   - Via Telegram, send: "What should I work on today?"
   - **Expected Response:**
     - Response within 10-15 seconds
     - No "_via Gemini fallback_" footer
     - Response should mention ADHD_Commander or task guidance

3. **Stop Ollama Service**
   ```bash
   # On EC2
   docker stop ollama

   # Verify stopped
   docker ps | grep ollama
   # Expected: No output (container stopped)
   ```

4. **Send Test Message During Failure**
   - Via Telegram, send: "Give me a priority task"
   - **Expected Response:**
     - Response within 15-25 seconds (Gemini latency)
     - Contains "_via Gemini fallback_" footer
     - Response quality similar to Ollama (task-related guidance)

5. **Verify Fallback Logging**
   ```bash
   # Check n8n console logs
   docker logs n8n --tail 50 | grep "AI_FALLBACK"
   # Expected: JSON log entry with event="ai_fallback_triggered"

   # Check database
   docker exec -it postgresql psql -U n8n -d n8n -c \
     "SELECT timestamp, chat_id, failure_type, provider, error_detail
      FROM ai_failures
      ORDER BY timestamp DESC
      LIMIT 1;"
   # Expected: 1 row with:
   #   - failure_type = 'ollama_timeout'
   #   - provider = 'ollama'
   #   - error_detail = 'Fallback to Gemini successful'
   ```

6. **Restore Ollama**
   ```bash
   docker start ollama

   # Wait for service ready
   sleep 10

   # Verify running
   docker ps | grep ollama
   ```

7. **Verify Recovery**
   - Via Telegram, send: "Status check"
   - **Expected Response:**
     - Response within 10-15 seconds
     - NO "_via Gemini fallback_" footer
     - System back to normal Ollama operation

**Success Criteria:**
- ✅ Ollama failure triggers Gemini fallback automatically
- ✅ Fallback response delivered within 30s
- ✅ Fallback event logged to `ai_failures` table
- ✅ System recovers when Ollama restored

**Pass/Fail:** _______

**Notes:**
```
[Record any observations, latency measurements, or issues]
```

---

### TC-5.2: Gemini Response Quality Comparison

**Objective:** Verify Gemini fallback produces equivalent routing quality to Ollama

**Prerequisites:**
- Ollama stopped (from TC-5.1)
- Fresh test session (no cached responses)

**Test Cases:**

#### Case 1: Tool Routing - System Status
**Input:** "Check system health"

**Ollama Response (baseline):**
```bash
# Restart Ollama, send message, record response
docker start ollama && sleep 10
# Send via Telegram: "Check system health"
# Record response: _________________________
```

**Gemini Response (fallback):**
```bash
# Stop Ollama, send message, record response
docker stop ollama
# Send via Telegram: "Check system health"
# Record response: _________________________
```

**Comparison Checklist:**
- [ ] Both responses mention system/infrastructure
- [ ] Both provide actionable guidance or status
- [ ] Both maintain CYBER-SQUIRE persona
- [ ] Response length similar (±100 words)
- [ ] Both are ADHD-friendly (bullets, bold actions)

#### Case 2: Tool Routing - ADHD Commander
**Input:** "I don't know where to start, help me focus"

**Ollama Response:**
```
[Record here]
```

**Gemini Response:**
```
[Record here]
```

**Comparison Checklist:**
- [ ] Both suggest task prioritization approach
- [ ] Both maintain consultative authority
- [ ] Both reference Notion or task context
- [ ] Tone and format consistent

#### Case 3: Tool Routing - Finance Manager
**Input:** "I spent $75 on groceries today"

**Ollama Response:**
```
[Record here]
```

**Gemini Response:**
```
[Record here]
```

**Comparison Checklist:**
- [ ] Both acknowledge transaction
- [ ] Both mention logging/tracking
- [ ] Both provide financial context if relevant

#### Case 4: Direct Conversation (No Tool)
**Input:** "Thanks for the help earlier"

**Ollama Response:**
```
[Record here]
```

**Gemini Response:**
```
[Record here]
```

**Comparison Checklist:**
- [ ] Both provide friendly acknowledgment
- [ ] Both maintain CYBER-SQUIRE persona
- [ ] Both are concise (<50 words)

#### Case 5: Fallback/Ambiguous Input
**Input:** "asdfqwer123"

**Ollama Response:**
```
[Record here]
```

**Gemini Response:**
```
[Record here]
```

**Comparison Checklist:**
- [ ] Both provide orientation (available capabilities)
- [ ] Both avoid apologizing excessively
- [ ] Both maintain helpful tone
- [ ] Both keep response under 100 words

**Success Criteria:**
- ✅ 4/5 test cases show equivalent routing quality
- ✅ No critical persona deviations in Gemini responses
- ✅ User experience remains consistent across providers

**Pass/Fail:** _______

**Quality Score:** _____ / 5

---

### TC-5.3: Fallback Event Logging

**Objective:** Verify all fallback events are logged with correct metadata

**Prerequisites:**
- Ollama stopped
- `ai_failures` table truncated

**Procedure:**

1. **Generate 5 Fallback Events**
   ```bash
   # Send 5 different messages via Telegram (1 minute apart):
   # 1. "What's my priority task?"
   # 2. "Check system health"
   # 3. "I spent $30 on lunch"
   # 4. "Hello"
   # 5. "Random text xyz123"
   ```

2. **Query All Logged Events**
   ```sql
   SELECT
     id,
     chat_id,
     failure_type,
     provider,
     message_id,
     timestamp,
     error_detail,
     resolved
   FROM ai_failures
   ORDER BY timestamp ASC;
   ```

3. **Verify Event Count**
   ```sql
   SELECT COUNT(*) as event_count FROM ai_failures;
   -- Expected: 5
   ```

4. **Verify Event Structure**
   Check each row has:
   - [ ] `chat_id` populated (your Telegram chat ID)
   - [ ] `failure_type` = 'ollama_timeout'
   - [ ] `provider` = 'ollama'
   - [ ] `message_id` is unique for each
   - [ ] `timestamp` in chronological order
   - [ ] `error_detail` = 'Fallback to Gemini successful'
   - [ ] `resolved` = FALSE (or TRUE if >1 hour old)

5. **Verify Timestamp Precision**
   ```sql
   SELECT
     id,
     timestamp,
     EXTRACT(EPOCH FROM (LEAD(timestamp) OVER (ORDER BY timestamp) - timestamp)) as seconds_between
   FROM ai_failures;
   -- Expected: seconds_between approximately 60 (1 minute)
   ```

6. **Test Auto-Resolution Trigger**
   ```sql
   -- Manually insert old failure
   INSERT INTO ai_failures (chat_id, failure_type, provider, message_id, error_detail, timestamp)
   VALUES ('test_chat', 'test_failure', 'test_provider', 999999, 'Old test failure', NOW() - INTERVAL '2 hours');

   -- Trigger auto-resolve by inserting new failure
   INSERT INTO ai_failures (chat_id, failure_type, provider, message_id, error_detail)
   VALUES ('test_chat', 'new_failure', 'ollama', 888888, 'New failure');

   -- Verify old failure resolved
   SELECT resolved, resolved_at FROM ai_failures WHERE message_id = 999999;
   -- Expected: resolved = TRUE, resolved_at = recent timestamp
   ```

7. **Verify Console Logs**
   ```bash
   docker logs n8n --since 10m | grep "AI_FALLBACK"
   # Expected: 5 JSON log entries with event="ai_fallback_triggered"
   ```

8. **Check Log Structure**
   Each log should contain:
   ```json
   {
     "event": "ai_fallback_triggered",
     "timestamp": "ISO-8601 format",
     "chat_id": "string",
     "provider": "gemini",
     "reason": "ollama_failure",
     "latencyMs": number,
     "success": true
   }
   ```

**Success Criteria:**
- ✅ All 5 fallback events logged to database
- ✅ Each log entry has required fields populated
- ✅ Timestamps are sequential and accurate
- ✅ Console logs match database entries
- ✅ Auto-resolution trigger works correctly

**Pass/Fail:** _______

---

### TC-5.4: Manual Escalation Prompt

**Objective:** Verify escalation notice appears after 3 consecutive AI failures

**Prerequisites:**
- Ollama stopped
- Gemini stopped (simulate dual failure) OR mock Gemini error

**Procedure:**

1. **Clear Previous Failures**
   ```sql
   TRUNCATE TABLE ai_failures;
   ```

2. **Simulate Dual AI Failure (Option A: Stop Gemini)**
   ```bash
   # Temporarily invalidate Gemini API key
   docker exec -it n8n sh
   # Edit environment or credential to cause Gemini to fail
   # (This is complex; see Option B for easier approach)
   ```

   **OR**

   **Simulate Dual AI Failure (Option B: Mock in Code)**
   - Temporarily modify "Handle Gemini Failure" node to always trigger
   - Deploy modified workflow
   - Send test messages

3. **Send First Failure Message**
   - Via Telegram, send: "Test message 1"
   - **Expected Response:**
     - Error message (not escalation yet)
     - Something like: "⚠️ AI systems experiencing issues..."
     - NO escalation header

4. **Verify Failure Logged**
   ```sql
   SELECT COUNT(*) FROM ai_failures WHERE resolved = FALSE;
   -- Expected: 1
   ```

5. **Send Second Failure Message**
   - Via Telegram, send: "Test message 2"
   - **Expected Response:**
     - Same error message
     - NO escalation header yet

6. **Verify Failure Count**
   ```sql
   SELECT COUNT(*) FROM ai_failures WHERE resolved = FALSE;
   -- Expected: 2
   ```

7. **Send Third Failure Message**
   - Via Telegram, send: "Test message 3"
   - **Expected Response:**
     - **Escalation header present:**
       ```
       ⚠️ **AI System Alert**

       Multiple AI failures detected (3 in last 10 min). Manual intervention may be needed.

       For urgent assistance, contact @ETcodin.

       ---

       [Original error message]
       ```

8. **Verify Escalation Logged**
   ```sql
   SELECT COUNT(*) FROM ai_failures WHERE resolved = FALSE;
   -- Expected: 3
   ```

9. **Test Escalation Query**
   ```sql
   SELECT
     chat_id,
     COUNT(*) as consecutive_failures,
     MAX(timestamp) as last_failure,
     STRING_AGG(DISTINCT failure_type, ', ') as failure_types
   FROM ai_failures
   WHERE timestamp > NOW() - INTERVAL '10 minutes'
     AND resolved = FALSE
   GROUP BY chat_id
   HAVING COUNT(*) >= 3;
   -- Expected: 1 row with consecutive_failures = 3
   ```

10. **Test Escalation Reset (>10 minutes)**
    ```bash
    # Wait 10 minutes OR manually age failures
    # SQL approach:
    ```
    ```sql
    UPDATE ai_failures
    SET timestamp = NOW() - INTERVAL '11 minutes'
    WHERE resolved = FALSE;
    ```

    - Send another message: "Test message 4"
    - **Expected Response:**
      - NO escalation header (failures too old)
      - Standard error message only

11. **Restore Services**
    ```bash
    # Start Ollama
    docker start ollama

    # Restore Gemini API key if invalidated
    # OR remove mock failure code if used
    ```

**Success Criteria:**
- ✅ First 2 failures: standard error, no escalation
- ✅ Third failure: escalation header present
- ✅ Escalation message includes failure count
- ✅ Escalation message includes contact info (@ETcodin)
- ✅ Escalation resets after 10 minutes
- ✅ Database query correctly identifies escalation scenario

**Pass/Fail:** _______

**Notes:**
```
[Record escalation timing, message format, any issues]
```

---

### TC-5.5: Gemini Quota Exhaustion Handling

**Objective:** Verify graceful handling when Gemini API quota is exhausted

**Prerequisites:**
- Ollama stopped (to force Gemini usage)
- Gemini API quota approaching limit OR mock 429 response

**Procedure:**

1. **Simulate Quota Exhaustion**

   **Option A: Actual Quota Exhaustion**
   ```bash
   # Send 1000+ requests to Gemini in <24 hours
   # (Not recommended; use Option B for testing)
   ```

   **Option B: Mock 429 Response**
   - Modify "Call Gemini API" node to return mock error:
   ```json
   {
     "error": {
       "code": 429,
       "message": "Resource has been exhausted (e.g. check quota).",
       "status": "RESOURCE_EXHAUSTED"
     }
   }
   ```
   - Deploy modified workflow

2. **Send Test Message**
   - Via Telegram, send: "What should I do?"
   - **Expected Response:**
     ```
     🔧 AI capacity temporarily limited. System will retry in 1 hour. For urgent tasks, contact @ETcodin directly.
     ```

3. **Verify Quota Error Logged**
   ```sql
   SELECT
     timestamp,
     failure_type,
     provider,
     error_detail
   FROM ai_failures
   ORDER BY timestamp DESC
   LIMIT 1;
   -- Expected:
   --   failure_type = 'quota' (if implemented) OR 'complete_failure'
   --   provider = 'gemini'
   --   error_detail contains '429' or 'quota'
   ```

4. **Verify NO Escalation on Quota**
   - Send 2 more messages (quota still exhausted)
   - **Expected:**
     - Same quota message
     - NO escalation header (quota is expected, not critical failure)

5. **Check Console Logs**
   ```bash
   docker logs n8n --tail 50 | grep -i "quota"
   # Expected: Log entry indicating quota exhaustion detected
   ```

6. **Restore Normal Operation**
   - Remove mock 429 response
   - Start Ollama: `docker start ollama`
   - Deploy normal workflow

**Success Criteria:**
- ✅ Quota exhaustion detected (429 or quota keyword)
- ✅ User-friendly quota message displayed
- ✅ Quota failures logged to database
- ✅ NO escalation triggered by quota errors
- ✅ System distinguishes quota from critical failures

**Pass/Fail:** _______

---

### TC-5.6: Graceful Recovery After Service Restoration

**Objective:** Verify system automatically returns to primary AI when available

**Prerequisites:**
- Ollama stopped (fallback active)
- Messages sent via Gemini

**Procedure:**

1. **Confirm Fallback Active**
   - Via Telegram, send: "Pre-recovery test"
   - **Expected:** Response with "_via Gemini fallback_"

2. **Restore Ollama Service**
   ```bash
   docker start ollama

   # Wait for model loading (may take 30-60 seconds)
   sleep 60

   # Verify Ollama ready
   curl http://localhost:11434/api/generate -d '{
     "model": "qwen2.5:7b",
     "prompt": "test",
     "stream": false
   }' | jq '.response'
   # Expected: Valid response
   ```

3. **Send Post-Recovery Message**
   - Via Telegram, send: "Post-recovery test"
   - **Expected Response:**
     - Response within 10-15 seconds (Ollama speed)
     - NO "_via Gemini fallback_" footer
     - Response quality consistent with Ollama

4. **Verify No Fallback Logging**
   ```sql
   SELECT COUNT(*) FROM ai_failures
   WHERE timestamp > NOW() - INTERVAL '5 minutes';
   -- Expected: 0 (no new failures after Ollama restored)
   ```

5. **Verify Execution Path**
   ```bash
   docker logs n8n --tail 30 | grep -E "(OLLAMA|GEMINI|FALLBACK)"
   # Expected: No recent FALLBACK logs
   ```

6. **Send Multiple Follow-up Messages**
   - Via Telegram, send 3 messages:
     1. "Check system health"
     2. "What's on my plate?"
     3. "I spent $20 on coffee"
   - **Expected:** All 3 handled by Ollama, no fallback indicators

7. **Verify Continuous Stability**
   ```sql
   SELECT
     DATE_TRUNC('minute', timestamp) as minute,
     COUNT(*) as failures
   FROM ai_failures
   WHERE timestamp > NOW() - INTERVAL '10 minutes'
   GROUP BY minute
   ORDER BY minute DESC;
   -- Expected: No entries (or only old pre-recovery entries)
   ```

**Success Criteria:**
- ✅ First message after recovery uses Ollama (no fallback)
- ✅ No fallback events logged post-recovery
- ✅ System stable for 10+ minutes after restoration
- ✅ All subsequent messages handled by primary AI
- ✅ No degraded performance after recovery

**Pass/Fail:** _______

---

## Test Summary

### Test Results Matrix

| Test Case | Pass/Fail | Notes | Date Tested |
|-----------|-----------|-------|-------------|
| TC-5.1: Timeout & Fallback | ☐ | | |
| TC-5.2: Response Quality | ☐ | | |
| TC-5.3: Event Logging | ☐ | | |
| TC-5.4: Escalation Prompt | ☐ | | |
| TC-5.5: Quota Handling | ☐ | | |
| TC-5.6: Graceful Recovery | ☐ | | |

### Success Criteria Validation

| Success Criterion | Status | Evidence |
|-------------------|--------|----------|
| SC-5.1: Ollama timeout (>30s) triggers Gemini fallback | ☐ | TC-5.1 result |
| SC-5.2: Gemini response quality matches Ollama | ☐ | TC-5.2 score ≥4/5 |
| SC-5.3: Fallback event logged with reason and timestamp | ☐ | TC-5.3 database verification |
| SC-5.4: Manual escalation after 3 consecutive failures | ☐ | TC-5.4 result |

**Overall Phase 5 Status:** ☐ PASS | ☐ FAIL

### Known Issues
```
[Document any bugs, edge cases, or limitations discovered during testing]
```

### Performance Metrics

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Ollama response time (healthy) | <10s | ___s | ☐ |
| Gemini fallback response time | <25s | ___s | ☐ |
| Fallback trigger latency | <2s | ___s | ☐ |
| Recovery detection time | <5s | ___s | ☐ |
| Database insert latency | <100ms | ___ms | ☐ |

### Recommendations

**Post-Testing Actions:**
- [ ] Document any response quality gaps in SUMMARY.md
- [ ] Tune escalation threshold if false positives occur
- [ ] Monitor Gemini quota usage in production
- [ ] Set up alerting for escalation events
- [ ] Create runbook for dual-AI failure scenarios

**Signed off by:** _______________ **Date:** ___________
