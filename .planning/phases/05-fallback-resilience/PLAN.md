# Phase 5: Fallback & Resilience Implementation Plan

## Overview
**Goal:** System degrades gracefully when primary AI (Ollama) is unavailable.

**Requirement:** ROUTE-05 - Gemini Flash-Lite fallback when Ollama fails/times out

## Success Criteria
- **SC-5.1:** Ollama timeout (>30s) triggers Gemini fallback automatically
- **SC-5.2:** Gemini response quality matches Ollama for routing
- **SC-5.3:** Fallback event logged with reason and timestamp
- **SC-5.4:** Manual escalation prompt appears after 3 consecutive AI failures

## Infrastructure Context

### Primary AI: Ollama
- **Model:** qwen2.5:7b
- **Location:** EC2 instance (localhost:11434)
- **Current timeout:** Default (likely 120s)
- **Target timeout:** 30s

### Fallback AI: Gemini
- **Model:** gemini-2.5-flash-lite (experimental)
- **Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent`
- **Rate limits:** 15 RPM, 1000 RPD (free tier)
- **API key:** Requires GEMINI_API_KEY environment variable

### Current Workflow Structure
**File:** `COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json`

**Key nodes:**
1. `ai-agent` (Supervisor Agent) - LangChain agent node
2. `ollama-model` (Ollama Qwen) - LLM provider node
3. Connection: `Ollama Qwen` → `Supervisor Agent` (ai_languageModel)

## Implementation Strategy

### 1. Dual-LLM Architecture
Instead of replacing Ollama with Gemini on failure, we'll implement a **try-catch wrapper** around the Supervisor Agent node:

```
[Log Incoming] → [Try Ollama Agent] → [Check Success] → [Format Output]
                                           ↓ (on failure)
                                      [Try Gemini Agent] → [Log Fallback]
                                           ↓ (on failure)
                                      [Escalation Handler]
```

### 2. Timeout Implementation
**Challenge:** n8n LangChain nodes don't expose direct timeout configuration.

**Solution:** Add timeout detection via PostgreSQL execution tracking:
1. Log execution start timestamp before agent invocation
2. Query execution duration after completion
3. If duration > 30s, treat as timeout for metrics (log warning)
4. Use n8n's workflow-level timeout (set to 35s) to force failure

### 3. Gemini Integration
**Method:** HTTP Request node with structured prompting

**Endpoint configuration:**
```json
{
  "method": "POST",
  "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent",
  "authentication": "genericCredentialType",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "contents": [{
      "parts": [{
        "text": "{{ $json.prompt }}"
      }]
    }],
    "generationConfig": {
      "temperature": 0.4,
      "maxOutputTokens": 512,
      "topP": 0.95
    },
    "safetySettings": [
      {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
      {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
      {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
      {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
    ]
  }
}
```

**Query parameter:** `?key={{ $credentials.apiKey }}`

### 4. Unified Response Format
Both Ollama and Gemini outputs must conform to:
```json
{
  "output": "string",
  "intermediate_steps": [],
  "_metadata": {
    "provider": "ollama" | "gemini",
    "model": "string",
    "latencyMs": number,
    "fallback": boolean
  }
}
```

### 5. Failure Counter
**Implementation:** PostgreSQL table + in-memory tracking

```sql
CREATE TABLE ai_failures (
  id SERIAL PRIMARY KEY,
  chat_id VARCHAR(50) NOT NULL,
  failure_type VARCHAR(20) NOT NULL, -- 'timeout', 'error', 'quota'
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  provider VARCHAR(20) NOT NULL, -- 'ollama', 'gemini'
  message_id BIGINT,
  error_detail TEXT
);

CREATE INDEX idx_ai_failures_chat_time ON ai_failures(chat_id, timestamp DESC);
```

**Escalation logic:**
```javascript
// Query last 3 failures for this chat_id within 10 minutes
const recentFailures = await queryFailures(chatId, 3, 600);

if (recentFailures.length >= 3) {
  return {
    escalate: true,
    message: "⚠️ AI systems experiencing issues. Manual intervention may be needed. Last 3 attempts failed. Please contact @ETcodin if urgent."
  };
}
```

### 6. Quota Exhaustion Handler
**Gemini daily quota:** 1000 requests/day

**Detection:** HTTP 429 response or quota-exceeded error

**Response:**
```javascript
if (response.statusCode === 429 || response.error?.includes('quota')) {
  logFailure(chatId, 'quota', 'gemini', errorDetail);

  return {
    text: "🔧 AI capacity temporarily limited. System will retry in 1 hour. For urgent tasks, contact @ETcodin directly.",
    fallback: true,
    retryAfter: 3600 // seconds
  };
}
```

## Node-by-Node Implementation

### New Nodes to Add

#### Node: "Ollama Agent Wrapper"
- **Type:** Code (JavaScript)
- **Position:** Replaces direct connection to "Supervisor Agent"
- **Purpose:** Add metadata and prepare for error handling
- **Code:**
```javascript
const inputData = $input.first().json;
const startTime = Date.now();

return {
  json: {
    ...inputData,
    _execution: {
      startTime,
      provider: 'ollama',
      attemptNumber: 1
    }
  }
};
```

#### Node: "Check Agent Success"
- **Type:** If (conditional)
- **Position:** After "Supervisor Agent"
- **Condition:** `{{ $json.output !== undefined && $json.output !== null }}`
- **Routes:**
  - **True:** → "Log Routing Decision" (existing path)
  - **False:** → "Prepare Gemini Fallback"

#### Node: "Prepare Gemini Fallback"
- **Type:** Code (JavaScript)
- **Position:** After failed Ollama attempt
- **Purpose:** Transform LangChain agent context into Gemini prompt
- **Code:**
```javascript
const inputCtx = $('Parse Input').first().json;
const memory = await queryRecentMessages(inputCtx.chatId, 5); // Get last 5 messages

// Build conversation context for Gemini
const conversationHistory = memory.map(msg =>
  `${msg.role === 'user' ? 'User' : 'Assistant'}: ${msg.content}`
).join('\n\n');

const systemPrompt = `You are CYBER-SQUIRE, Emmanuel's AI operations commander...`; // Reuse from Supervisor Agent

const fullPrompt = `${systemPrompt}

## Recent Conversation
${conversationHistory}

## Current Message
User: ${inputCtx.text}

Respond as CYBER-SQUIRE. Keep responses under 200 words. Lead with the answer.`;

return {
  json: {
    prompt: fullPrompt,
    chatId: inputCtx.chatId,
    messageId: inputCtx.messageId,
    originalInput: inputCtx.text,
    _execution: {
      startTime: $('Ollama Agent Wrapper').first().json._execution.startTime,
      provider: 'gemini',
      attemptNumber: 2,
      fallbackReason: 'ollama_failure'
    }
  }
};
```

#### Node: "Call Gemini API"
- **Type:** HTTP Request
- **Position:** After "Prepare Gemini Fallback"
- **Configuration:**
  - **Method:** POST
  - **URL:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={{ $credentials.geminiApiKey }}`
  - **Authentication:** None (API key in query param)
  - **Headers:** `Content-Type: application/json`
  - **Body:**
```json
{
  "contents": [{
    "parts": [{"text": "={{ $json.prompt }}"}]
  }],
  "generationConfig": {
    "temperature": 0.4,
    "maxOutputTokens": 512,
    "topP": 0.95
  },
  "safetySettings": [
    {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
  ]
}
```

#### Node: "Parse Gemini Response"
- **Type:** Code (JavaScript)
- **Position:** After "Call Gemini API"
- **Purpose:** Transform Gemini format to match Ollama agent output
- **Code:**
```javascript
const geminiResponse = $input.first().json;
const executionMeta = $('Prepare Gemini Fallback').first().json._execution;

// Gemini response structure:
// { candidates: [{ content: { parts: [{ text: "..." }] } }] }

const responseText = geminiResponse.candidates?.[0]?.content?.parts?.[0]?.text ||
                     "I apologize, but I'm having trouble processing your request. Please try again.";

const endTime = Date.now();
const latencyMs = endTime - executionMeta.startTime;

// Append fallback indicator
const markedResponse = responseText + "\n\n_via Gemini fallback_";

return {
  json: {
    output: markedResponse,
    intermediate_steps: [],
    _metadata: {
      provider: 'gemini',
      model: 'gemini-2.5-flash-lite',
      latencyMs,
      fallback: true,
      attemptNumber: executionMeta.attemptNumber
    }
  }
};
```

#### Node: "Log Fallback Event"
- **Type:** Code (JavaScript)
- **Position:** After "Parse Gemini Response"
- **Purpose:** Log fallback event and check failure counter
- **Code:**
```javascript
const response = $input.first().json;
const inputCtx = $('Parse Input').first().json;
const timestamp = new Date().toISOString();

const logEntry = {
  event: 'ai_fallback_triggered',
  timestamp,
  chat_id: inputCtx.chatId,
  provider: 'gemini',
  reason: 'ollama_failure',
  latencyMs: response._metadata.latencyMs,
  success: true
};

console.log('AI_FALLBACK:', JSON.stringify(logEntry));

// Log to PostgreSQL
await $this.query(
  `INSERT INTO ai_failures (chat_id, failure_type, provider, message_id, error_detail)
   VALUES ($1, $2, $3, $4, $5)`,
  [inputCtx.chatId, 'ollama_timeout', 'ollama', inputCtx.messageId, 'Fallback to Gemini successful']
);

// Check recent failures
const recentFailures = await $this.query(
  `SELECT COUNT(*) as count FROM ai_failures
   WHERE chat_id = $1
   AND timestamp > NOW() - INTERVAL '10 minutes'`,
  [inputCtx.chatId]
);

const failureCount = parseInt(recentFailures[0].count);

return {
  json: {
    ...response,
    _escalation: {
      needed: failureCount >= 3,
      failureCount
    }
  }
};
```

#### Node: "Check Escalation Needed"
- **Type:** If (conditional)
- **Position:** After "Log Fallback Event"
- **Condition:** `{{ $json._escalation.needed === true }}`
- **Routes:**
  - **True:** → "Send Escalation Notice"
  - **False:** → "Log Routing Decision" (merge with main path)

#### Node: "Send Escalation Notice"
- **Type:** Code (JavaScript)
- **Position:** After escalation check (true branch)
- **Purpose:** Prepend escalation warning to response
- **Code:**
```javascript
const response = $input.first().json;
const failureCount = response._escalation.failureCount;

const escalationMessage = `⚠️ **AI System Alert**\n\nMultiple AI failures detected (${failureCount} in last 10 min). Manual intervention may be needed.\n\nFor urgent assistance, contact @ETcodin.\n\n---\n\n`;

return {
  json: {
    ...response,
    output: escalationMessage + response.output
  }
};
```

#### Node: "Handle Gemini Failure"
- **Type:** Code (JavaScript)
- **Position:** Error handler for "Call Gemini API"
- **Purpose:** Ultimate fallback when both AIs fail
- **Code:**
```javascript
const inputCtx = $('Parse Input').first().json;
const error = $input.first().json.error || 'Unknown error';
const timestamp = new Date().toISOString();

console.log('GEMINI_FALLBACK_FAILED:', JSON.stringify({
  timestamp,
  chat_id: inputCtx.chatId,
  error
}));

// Log dual failure
await $this.query(
  `INSERT INTO ai_failures (chat_id, failure_type, provider, message_id, error_detail)
   VALUES ($1, $2, $3, $4, $5)`,
  [inputCtx.chatId, 'complete_failure', 'gemini', inputCtx.messageId, error]
);

// Check if quota exhausted
const isQuotaError = error.includes('429') || error.includes('quota');

const fallbackMessage = isQuotaError
  ? "🔧 AI capacity temporarily limited. System will retry in 1 hour. For urgent tasks, contact @ETcodin directly."
  : "⚠️ AI systems experiencing issues. Your message has been logged. Please try again in a few moments or contact @ETcodin if urgent.";

return {
  json: {
    output: fallbackMessage,
    _metadata: {
      provider: 'none',
      fallback: true,
      complete_failure: true,
      error_type: isQuotaError ? 'quota_exhausted' : 'system_error'
    }
  }
};
```

## Updated Workflow Connections

### Modified Connections
```javascript
{
  "Log Incoming Message": {
    "main": [[{ "node": "Ollama Agent Wrapper", "type": "main", "index": 0 }]]
  },
  "Ollama Agent Wrapper": {
    "main": [[{ "node": "Supervisor Agent", "type": "main", "index": 0 }]]
  },
  "Supervisor Agent": {
    "main": [[{ "node": "Check Agent Success", "type": "main", "index": 0 }]]
  },
  "Check Agent Success": {
    "main": [
      [{ "node": "Log Routing Decision", "type": "main", "index": 0 }], // Success path
      [{ "node": "Prepare Gemini Fallback", "type": "main", "index": 0 }] // Failure path
    ]
  },
  "Prepare Gemini Fallback": {
    "main": [[{ "node": "Call Gemini API", "type": "main", "index": 0 }]]
  },
  "Call Gemini API": {
    "main": [[{ "node": "Parse Gemini Response", "type": "main", "index": 0 }]],
    "error": [[{ "node": "Handle Gemini Failure", "type": "main", "index": 0 }]]
  },
  "Parse Gemini Response": {
    "main": [[{ "node": "Log Fallback Event", "type": "main", "index": 0 }]]
  },
  "Log Fallback Event": {
    "main": [[{ "node": "Check Escalation Needed", "type": "main", "index": 0 }]]
  },
  "Check Escalation Needed": {
    "main": [
      [{ "node": "Send Escalation Notice", "type": "main", "index": 0 }], // Escalation needed
      [{ "node": "Log Routing Decision", "type": "main", "index": 0 }]  // Continue normal flow
    ]
  },
  "Send Escalation Notice": {
    "main": [[{ "node": "Log Routing Decision", "type": "main", "index": 0 }]]
  },
  "Handle Gemini Failure": {
    "main": [[{ "node": "Log Routing Decision", "type": "main", "index": 0 }]]
  }
}
```

## Database Schema Updates

### New Table: ai_failures
```sql
CREATE TABLE ai_failures (
  id SERIAL PRIMARY KEY,
  chat_id VARCHAR(50) NOT NULL,
  failure_type VARCHAR(20) NOT NULL, -- 'timeout', 'error', 'quota', 'complete_failure'
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  provider VARCHAR(20) NOT NULL, -- 'ollama', 'gemini', 'none'
  message_id BIGINT,
  error_detail TEXT,
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMP
);

CREATE INDEX idx_ai_failures_chat_time ON ai_failures(chat_id, timestamp DESC);
CREATE INDEX idx_ai_failures_unresolved ON ai_failures(resolved) WHERE resolved = FALSE;

-- Auto-cleanup: Mark old failures as resolved after 1 hour
CREATE OR REPLACE FUNCTION auto_resolve_old_failures()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE ai_failures
  SET resolved = TRUE, resolved_at = NOW()
  WHERE timestamp < NOW() - INTERVAL '1 hour'
    AND resolved = FALSE;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_resolve_failures
  AFTER INSERT ON ai_failures
  EXECUTE FUNCTION auto_resolve_old_failures();
```

## Environment Configuration

### Required Environment Variables
Add to `COREDIRECTIVE_ENGINE/.env`:
```bash
# Gemini API (Fallback AI)
GEMINI_API_KEY=your_gemini_api_key_here

# Ollama Timeout (optional override)
OLLAMA_TIMEOUT_MS=30000
```

Add to `.env.example`:
```bash
# Gemini API (Fallback AI)
GEMINI_API_KEY=your_gemini_api_key_here
```

### n8n Credentials Setup
1. Navigate to n8n Credentials
2. Create new credential: "Generic Credential Type"
   - **Name:** Gemini API
   - **Type:** Header Auth
   - **Add field:** `apiKey` = `{{ $env.GEMINI_API_KEY }}`

## Testing Strategy

### Test Cases

#### TC-5.1: Ollama Timeout Detection
**Setup:** Simulate Ollama service down
```bash
docker stop ollama  # On EC2
```

**Test message:** "What should I work on today?"

**Expected result:**
- Ollama fails after n8n workflow timeout
- Gemini fallback triggered automatically
- Response contains "_via Gemini fallback_"
- `ai_failures` table has new entry with `failure_type='timeout'`

**Validation:**
```sql
SELECT * FROM ai_failures
WHERE failure_type = 'timeout'
ORDER BY timestamp DESC LIMIT 1;
```

#### TC-5.2: Gemini Response Quality
**Setup:** Ollama service down, Gemini available

**Test messages:**
1. "Check system health" (should route to System Status tool)
2. "What's on my plate?" (should route to ADHD Commander)
3. "I spent $20 on lunch" (should route to Finance Manager)
4. "Hello" (should respond conversationally)

**Expected result:**
- All routing decisions match Ollama's behavior
- Tool calls are identical
- Response style is consistent

**Validation:** Compare logs from `routing_decision` table

#### TC-5.3: Fallback Event Logging
**Setup:** Ollama service down

**Test message:** "Give me a task"

**Expected result:**
1. Console log: `AI_FALLBACK: {"event":"ai_fallback_triggered",...}`
2. Database entry in `ai_failures`
3. Response includes timestamp metadata

**Validation:**
```sql
SELECT
  timestamp,
  failure_type,
  provider,
  error_detail
FROM ai_failures
WHERE chat_id = 'test_chat_id'
ORDER BY timestamp DESC;
```

#### TC-5.4: Escalation After 3 Failures
**Setup:** Both Ollama and Gemini down (or Gemini quota exhausted)

**Test:** Send 3 consecutive messages within 10 minutes

**Expected result:**
- First 2 messages: Standard error response
- 3rd message: Escalation warning prepended
- Message contains "⚠️ **AI System Alert**" and contact info

**Validation:** Check Telegram response text

#### TC-5.5: Quota Exhaustion Handling
**Setup:** Mock Gemini 429 response

**Test message:** Any message triggering fallback

**Expected result:**
- Response: "🔧 AI capacity temporarily limited..."
- `ai_failures` entry with `failure_type='quota'`
- No escalation (quota is expected, not a system failure)

#### TC-5.6: Graceful Recovery
**Setup:** Ollama down, then restored

**Test:**
1. Send message (triggers Gemini fallback)
2. Restart Ollama: `docker start ollama`
3. Send another message

**Expected result:**
- First message uses Gemini
- Second message uses Ollama (primary restored)
- No escalation triggered

## Deployment Checklist

### Pre-deployment
- [ ] Get Gemini API key from https://aistudio.google.com/apikey
- [ ] Add `GEMINI_API_KEY` to EC2 `.env` file
- [ ] Create n8n credential for Gemini API
- [ ] Deploy `ai_failures` table schema
- [ ] Test Gemini API connectivity from EC2

### Deployment
- [ ] Backup current `workflow_supervisor_agent.json`
- [ ] Import updated workflow JSON
- [ ] Verify all nodes connected correctly
- [ ] Update workflow settings (timeout to 35s)
- [ ] Enable error workflow connection

### Post-deployment
- [ ] Run TC-5.1 (timeout detection)
- [ ] Run TC-5.2 (response quality)
- [ ] Run TC-5.3 (logging)
- [ ] Run TC-5.4 (escalation)
- [ ] Monitor logs for 24 hours
- [ ] Create dashboard query for fallback metrics

## Monitoring & Metrics

### Key Queries

#### Fallback Rate (Last 24h)
```sql
SELECT
  COUNT(*) FILTER (WHERE provider = 'gemini') as gemini_fallbacks,
  COUNT(*) FILTER (WHERE provider = 'ollama') as ollama_failures,
  COUNT(*) as total_failures,
  ROUND(100.0 * COUNT(*) FILTER (WHERE provider = 'gemini') / NULLIF(COUNT(*), 0), 2) as fallback_percentage
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '24 hours';
```

#### Escalation Events
```sql
SELECT
  chat_id,
  COUNT(*) as failure_count,
  MAX(timestamp) as last_failure,
  STRING_AGG(DISTINCT failure_type, ', ') as failure_types
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '1 hour'
GROUP BY chat_id
HAVING COUNT(*) >= 3
ORDER BY failure_count DESC;
```

#### Provider Reliability
```sql
SELECT
  provider,
  failure_type,
  COUNT(*) as count,
  DATE_TRUNC('hour', timestamp) as hour
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY provider, failure_type, hour
ORDER BY hour DESC, count DESC;
```

### Alerting Thresholds
- **Warning:** >10% fallback rate in 1 hour
- **Critical:** >3 escalations in 1 hour
- **Info:** Gemini quota approaching (>800 requests in 24h)

## Risk Mitigation

### Risk 1: Gemini API Unavailable
**Impact:** Complete AI failure

**Mitigation:**
- Graceful degradation with static responses
- "Handle Gemini Failure" node provides user guidance
- Escalation to manual contact

### Risk 2: Prompt Injection Differences
**Impact:** Different tool routing behavior between Ollama and Gemini

**Mitigation:**
- Identical system prompts
- Pre-deployment testing with diverse inputs
- Routing decision logging for comparison

### Risk 3: Gemini Quota Exhaustion
**Impact:** Fallback unavailable during high-traffic periods

**Mitigation:**
- Quota monitoring
- Consider upgrading to paid tier if needed
- Static response as ultimate fallback

### Risk 4: Increased Latency
**Impact:** Gemini API calls may be slower than local Ollama

**Mitigation:**
- Accept increased latency as tradeoff for availability
- Log latency metrics
- Consider response streaming if latency >10s

## Success Metrics

### Quantitative
- **Availability:** System uptime >99.5% (including fallback)
- **MTTR:** Mean time to recovery <30s (via fallback)
- **Fallback accuracy:** >90% correct tool routing
- **Escalation precision:** <5% false positives

### Qualitative
- User never sees "system unavailable" message
- Fallback transitions are seamless
- Escalation messages are clear and actionable

## Rollback Plan
If fallback implementation causes issues:

1. **Immediate rollback:**
   ```bash
   # Restore backup workflow
   cp workflow_supervisor_agent_backup.json workflow_supervisor_agent.json
   ```

2. **Database cleanup:**
   ```sql
   DROP TABLE IF EXISTS ai_failures;
   ```

3. **Remove Gemini credential** from n8n

4. **Document failure reason** in `.planning/phases/05-fallback-resilience/ROLLBACK.md`

## Next Phase Dependencies
Phase 6 (Observability) will consume:
- `ai_failures` table for reliability dashboards
- Fallback rate metrics for SLA tracking
- Escalation events for incident response
