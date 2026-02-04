# Phase 5: Fallback & Resilience - Implementation Guide

## Pre-Implementation Checklist

### 1. Obtain Gemini API Key
```bash
# Visit https://aistudio.google.com/apikey
# Create new API key
# Copy key to clipboard
```

### 2. Configure Environment Variables
```bash
# SSH to EC2 instance
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244

# Navigate to COREDIRECTIVE_ENGINE directory
cd /home/ec2-user/COREDIRECTIVE_ENGINE

# Edit .env file
nano .env

# Add the following line:
GEMINI_API_KEY=your_actual_api_key_here

# Save and exit (Ctrl+X, Y, Enter)

# Restart Docker containers to load new env var
docker-compose restart
```

### 3. Update Local .env.example
```bash
# On local machine
cd /Users/et/cyber-squire-ops

# Edit .env.example
echo "\n# Gemini API (Fallback AI)\nGEMINI_API_KEY=your_gemini_api_key_here" >> .env.example
```

### 4. Create Database Schema
```bash
# SSH to EC2
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244

# Access PostgreSQL
docker exec -it postgresql psql -U n8n -d n8n

# Execute schema creation
CREATE TABLE ai_failures (
  id SERIAL PRIMARY KEY,
  chat_id VARCHAR(50) NOT NULL,
  failure_type VARCHAR(20) NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  provider VARCHAR(20) NOT NULL,
  message_id BIGINT,
  error_detail TEXT,
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMP
);

CREATE INDEX idx_ai_failures_chat_time ON ai_failures(chat_id, timestamp DESC);
CREATE INDEX idx_ai_failures_unresolved ON ai_failures(resolved) WHERE resolved = FALSE;

-- Auto-cleanup function
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

-- Verify table creation
\d ai_failures

-- Exit psql
\q
```

### 5. Backup Current Workflow
```bash
# On local machine
cd /Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE

# Create backup
cp workflow_supervisor_agent.json workflow_supervisor_agent_backup_$(date +%Y%m%d_%H%M%S).json

# Verify backup
ls -la workflow_supervisor_agent_backup_*
```

## Implementation Steps

### Step 1: Create n8n Credential for Gemini

1. Access n8n web interface: `http://54.234.155.244:5678`
2. Navigate to **Credentials** → **Add Credential**
3. Search for "HTTP Request" credential type
4. Configure:
   - **Name:** `Gemini API`
   - **Authentication:** `Generic Credential Type`
   - **Add field:**
     - **Name:** `apiKey`
     - **Value:** `{{ $env.GEMINI_API_KEY }}`
5. Click **Save**

### Step 2: Add New Nodes to Workflow

Open `workflow_supervisor_agent.json` and add the following nodes to the `nodes` array:

#### Node 1: Ollama Agent Wrapper
```json
{
  "parameters": {
    "jsCode": "const inputData = $input.first().json;\nconst startTime = Date.now();\n\nreturn {\n  json: {\n    ...inputData,\n    _execution: {\n      startTime,\n      provider: 'ollama',\n      attemptNumber: 1\n    }\n  }\n};"
  },
  "id": "ollama-wrapper",
  "name": "Ollama Agent Wrapper",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [1340, 520]
}
```

#### Node 2: Check Agent Success
```json
{
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict"
      },
      "conditions": [
        {
          "id": "output-exists",
          "leftValue": "={{ $json.output !== undefined && $json.output !== null && $json.output !== '' }}",
          "rightValue": true,
          "operator": {
            "type": "boolean",
            "operation": "equals"
          }
        }
      ],
      "combinator": "and"
    },
    "options": {}
  },
  "id": "check-success",
  "name": "Check Agent Success",
  "type": "n8n-nodes-base.if",
  "typeVersion": 2,
  "position": [1780, 520]
}
```

#### Node 3: Prepare Gemini Fallback
```json
{
  "parameters": {
    "jsCode": "const inputCtx = $('Parse Input').first().json;\n\n// Get chat memory from PostgreSQL\nconst memoryQuery = `\n  SELECT role, content, created_at\n  FROM chat_memory\n  WHERE session_id = $1\n  ORDER BY created_at DESC\n  LIMIT 5\n`;\n\nlet conversationHistory = '';\ntry {\n  const memoryResults = await this.helpers.dbQuery(memoryQuery, [inputCtx.chatId]);\n  conversationHistory = memoryResults\n    .reverse()\n    .map(msg => `${msg.role === 'user' ? 'User' : 'Assistant'}: ${msg.content}`)\n    .join('\\n\\n');\n} catch (error) {\n  console.log('Memory fetch failed, proceeding without context:', error.message);\n}\n\nconst systemPrompt = `You are CYBER-SQUIRE, Emmanuel Tigoue's AI operations commander. You maintain Consultative Authority - you advise decisively, not passively.\n\n## CORE IDENTITY\n- User: Emmanuel (ET), Security Solutions Architect (CASP+, CCNA), Sickle Cell warrior\n- Framework: 12-Week Year (12WY) with ADHD-optimized execution\n- Energy: Finite and precious - every interaction must be high-ROI\n\n## RESPONSE FORMAT (ADHD-FRIENDLY)\n1. Lead with the answer - no preambles\n2. Use bullets and visual hierarchy\n3. Bold key actions: **Do this now**\n4. Keep responses under 200 words unless detail requested\n5. End with ONE clear next action\n\n## INSTRUCTIONS\nRespond to the user's message below. Be direct, actionable, and consultative. Current time: ${new Date().toISOString()}.`;\n\nconst fullPrompt = conversationHistory\n  ? `${systemPrompt}\\n\\n## Recent Conversation\\n${conversationHistory}\\n\\n## Current Message\\nUser: ${inputCtx.text}\\n\\nRespond as CYBER-SQUIRE.`\n  : `${systemPrompt}\\n\\nUser: ${inputCtx.text}\\n\\nRespond as CYBER-SQUIRE.`;\n\nreturn {\n  json: {\n    prompt: fullPrompt,\n    chatId: inputCtx.chatId,\n    messageId: inputCtx.messageId,\n    originalInput: inputCtx.text,\n    _execution: {\n      startTime: $('Ollama Agent Wrapper').first().json._execution.startTime,\n      provider: 'gemini',\n      attemptNumber: 2,\n      fallbackReason: 'ollama_failure'\n    }\n  }\n};"
  },
  "id": "prepare-gemini",
  "name": "Prepare Gemini Fallback",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [1900, 700]
}
```

#### Node 4: Call Gemini API
```json
{
  "parameters": {
    "method": "POST",
    "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent",
    "authentication": "predefinedCredentialType",
    "nodeCredentialType": "geminiApi",
    "sendQuery": true,
    "queryParameters": {
      "parameters": [
        {
          "name": "key",
          "value": "={{ $credentials.apiKey }}"
        }
      ]
    },
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{ JSON.stringify({\n  contents: [{\n    parts: [{ text: $json.prompt }]\n  }],\n  generationConfig: {\n    temperature: 0.4,\n    maxOutputTokens: 512,\n    topP: 0.95\n  },\n  safetySettings: [\n    { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },\n    { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },\n    { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },\n    { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' }\n  ]\n}) }}",
    "options": {
      "timeout": 15000
    }
  },
  "id": "call-gemini",
  "name": "Call Gemini API",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [2120, 700],
  "credentials": {
    "geminiApi": {
      "id": "gemini-api-cred-id",
      "name": "Gemini API"
    }
  },
  "continueOnFail": true
}
```

#### Node 5: Parse Gemini Response
```json
{
  "parameters": {
    "jsCode": "const geminiResponse = $input.first().json;\nconst executionMeta = $('Prepare Gemini Fallback').first().json._execution;\n\n// Check if request failed\nif (geminiResponse.error || !geminiResponse.candidates) {\n  throw new Error('Gemini API call failed: ' + (geminiResponse.error?.message || 'No candidates returned'));\n}\n\n// Extract response text from Gemini structure\nconst responseText = geminiResponse.candidates?.[0]?.content?.parts?.[0]?.text || \n                     \"I apologize, but I'm having trouble processing your request. Please try again.\";\n\nconst endTime = Date.now();\nconst latencyMs = endTime - executionMeta.startTime;\n\n// Append fallback indicator\nconst markedResponse = responseText + \"\\n\\n_via Gemini fallback_\";\n\nreturn {\n  json: {\n    output: markedResponse,\n    intermediate_steps: [],\n    _metadata: {\n      provider: 'gemini',\n      model: 'gemini-2.5-flash-lite',\n      latencyMs,\n      fallback: true,\n      attemptNumber: executionMeta.attemptNumber\n    },\n    _execution: executionMeta\n  }\n};"
  },
  "id": "parse-gemini",
  "name": "Parse Gemini Response",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2340, 700]
}
```

#### Node 6: Log Fallback Event
```json
{
  "parameters": {
    "jsCode": "const response = $input.first().json;\nconst inputCtx = $('Parse Input').first().json;\nconst timestamp = new Date().toISOString();\n\nconst logEntry = {\n  event: 'ai_fallback_triggered',\n  timestamp,\n  chat_id: inputCtx.chatId,\n  provider: 'gemini',\n  reason: 'ollama_failure',\n  latencyMs: response._metadata.latencyMs,\n  success: true\n};\n\nconsole.log('AI_FALLBACK:', JSON.stringify(logEntry));\n\n// Log to PostgreSQL\nconst insertQuery = `\n  INSERT INTO ai_failures (chat_id, failure_type, provider, message_id, error_detail)\n  VALUES ($1, $2, $3, $4, $5)\n`;\n\nawait this.helpers.dbQuery(\n  insertQuery,\n  [inputCtx.chatId, 'ollama_timeout', 'ollama', inputCtx.messageId, 'Fallback to Gemini successful']\n);\n\n// Check recent failures for escalation\nconst failureCheckQuery = `\n  SELECT COUNT(*) as count FROM ai_failures\n  WHERE chat_id = $1\n  AND timestamp > NOW() - INTERVAL '10 minutes'\n  AND resolved = FALSE\n`;\n\nconst recentFailures = await this.helpers.dbQuery(failureCheckQuery, [inputCtx.chatId]);\nconst failureCount = parseInt(recentFailures[0]?.count || 0);\n\nreturn {\n  json: {\n    ...response,\n    _escalation: {\n      needed: failureCount >= 3,\n      failureCount\n    }\n  }\n};"
  },
  "id": "log-fallback",
  "name": "Log Fallback Event",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2560, 700],
  "credentials": {
    "postgres": {
      "id": "cd-postgres-main",
      "name": "CD PostgreSQL"
    }
  }
}
```

#### Node 7: Check Escalation Needed
```json
{
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict"
      },
      "conditions": [
        {
          "id": "escalation-check",
          "leftValue": "={{ $json._escalation.needed === true }}",
          "rightValue": true,
          "operator": {
            "type": "boolean",
            "operation": "equals"
          }
        }
      ],
      "combinator": "and"
    },
    "options": {}
  },
  "id": "check-escalation",
  "name": "Check Escalation Needed",
  "type": "n8n-nodes-base.if",
  "typeVersion": 2,
  "position": [2780, 700]
}
```

#### Node 8: Send Escalation Notice
```json
{
  "parameters": {
    "jsCode": "const response = $input.first().json;\nconst failureCount = response._escalation.failureCount;\n\nconst escalationMessage = `⚠️ **AI System Alert**\\n\\nMultiple AI failures detected (${failureCount} in last 10 min). Manual intervention may be needed.\\n\\nFor urgent assistance, contact @ETcodin.\\n\\n---\\n\\n`;\n\nreturn {\n  json: {\n    ...response,\n    output: escalationMessage + response.output\n  }\n};"
  },
  "id": "send-escalation",
  "name": "Send Escalation Notice",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2900, 580]
}
```

#### Node 9: Handle Gemini Failure
```json
{
  "parameters": {
    "jsCode": "const inputCtx = $('Parse Input').first().json;\nconst error = $input.first().json.error?.message || $input.first().json.message || 'Unknown error';\nconst timestamp = new Date().toISOString();\n\nconsole.log('GEMINI_FALLBACK_FAILED:', JSON.stringify({\n  timestamp,\n  chat_id: inputCtx.chatId,\n  error\n}));\n\n// Log dual failure\nconst insertQuery = `\n  INSERT INTO ai_failures (chat_id, failure_type, provider, message_id, error_detail)\n  VALUES ($1, $2, $3, $4, $5)\n`;\n\nawait this.helpers.dbQuery(\n  insertQuery,\n  [inputCtx.chatId, 'complete_failure', 'gemini', inputCtx.messageId, error]\n);\n\n// Check if quota exhausted\nconst isQuotaError = error.includes('429') || error.toLowerCase().includes('quota') || error.toLowerCase().includes('rate limit');\n\nconst fallbackMessage = isQuotaError\n  ? \"🔧 AI capacity temporarily limited. System will retry in 1 hour. For urgent tasks, contact @ETcodin directly.\"\n  : \"⚠️ AI systems experiencing issues. Your message has been logged. Please try again in a few moments or contact @ETcodin if urgent.\";\n\nreturn {\n  json: {\n    output: fallbackMessage,\n    intermediate_steps: [],\n    _metadata: {\n      provider: 'none',\n      fallback: true,\n      complete_failure: true,\n      error_type: isQuotaError ? 'quota_exhausted' : 'system_error'\n    }\n  }\n};"
  },
  "id": "handle-gemini-failure",
  "name": "Handle Gemini Failure",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2340, 880],
  "credentials": {
    "postgres": {
      "id": "cd-postgres-main",
      "name": "CD PostgreSQL"
    }
  }
}
```

### Step 3: Update Workflow Connections

Modify the `connections` section of `workflow_supervisor_agent.json`:

```json
{
  "connections": {
    "Telegram Ingestion": {
      "main": [[{ "node": "Extract Message ID", "type": "main", "index": 0 }]]
    },
    "Extract Message ID": {
      "main": [[{ "node": "Check Duplicate", "type": "main", "index": 0 }]]
    },
    "Check Duplicate": {
      "main": [[{ "node": "Is Duplicate?", "type": "main", "index": 0 }]]
    },
    "Is Duplicate?": {
      "main": [
        [{ "node": "Skip Duplicate", "type": "main", "index": 0 }],
        [{ "node": "Parse Input", "type": "main", "index": 0 }]
      ]
    },
    "Parse Input": {
      "main": [[{ "node": "Log Incoming Message", "type": "main", "index": 0 }]]
    },
    "Log Incoming Message": {
      "main": [[{ "node": "Ollama Agent Wrapper", "type": "main", "index": 0 }]]
    },
    "Ollama Agent Wrapper": {
      "main": [[{ "node": "Supervisor Agent", "type": "main", "index": 0 }]]
    },
    "Chat Memory": {
      "ai_memory": [[{ "node": "Supervisor Agent", "type": "ai_memory", "index": 0 }]]
    },
    "Ollama Qwen": {
      "ai_languageModel": [[{ "node": "Supervisor Agent", "type": "ai_languageModel", "index": 0 }]]
    },
    "ADHD Commander Tool": {
      "ai_tool": [[{ "node": "Supervisor Agent", "type": "ai_tool", "index": 0 }]]
    },
    "Finance Manager Tool": {
      "ai_tool": [[{ "node": "Supervisor Agent", "type": "ai_tool", "index": 0 }]]
    },
    "System Status Tool": {
      "ai_tool": [[{ "node": "Supervisor Agent", "type": "ai_tool", "index": 0 }]]
    },
    "Supervisor Agent": {
      "main": [[{ "node": "Check Agent Success", "type": "main", "index": 0 }]]
    },
    "Check Agent Success": {
      "main": [
        [{ "node": "Log Routing Decision", "type": "main", "index": 0 }],
        [{ "node": "Prepare Gemini Fallback", "type": "main", "index": 0 }]
      ]
    },
    "Prepare Gemini Fallback": {
      "main": [[{ "node": "Call Gemini API", "type": "main", "index": 0 }]]
    },
    "Call Gemini API": {
      "main": [[{ "node": "Parse Gemini Response", "type": "main", "index": 0 }]]
    },
    "Parse Gemini Response": {
      "main": [[{ "node": "Log Fallback Event", "type": "main", "index": 0 }]]
    },
    "Log Fallback Event": {
      "main": [[{ "node": "Check Escalation Needed", "type": "main", "index": 0 }]]
    },
    "Check Escalation Needed": {
      "main": [
        [{ "node": "Send Escalation Notice", "type": "main", "index": 0 }],
        [{ "node": "Log Routing Decision", "type": "main", "index": 0 }]
      ]
    },
    "Send Escalation Notice": {
      "main": [[{ "node": "Log Routing Decision", "type": "main", "index": 0 }]]
    },
    "Handle Gemini Failure": {
      "main": [[{ "node": "Log Routing Decision", "type": "main", "index": 0 }]]
    },
    "Log Routing Decision": {
      "main": [[{ "node": "Format Output", "type": "main", "index": 0 }]]
    },
    "Format Output": {
      "main": [[{ "node": "Log Outgoing Response", "type": "main", "index": 0 }]]
    },
    "Log Outgoing Response": {
      "main": [[{ "node": "Send Response", "type": "main", "index": 0 }]]
    },
    "Send Response": {
      "main": [[{ "node": "Mark Complete", "type": "main", "index": 0 }]]
    }
  }
}
```

### Step 4: Update Workflow Metadata

Update the `meta` section:

```json
{
  "meta": {
    "notes": "Supervisor Agent v4.0 (Resilient AI Routing): Added Gemini 2.5 Flash-Lite fallback for Ollama failures. Features: (1) 30s timeout detection, (2) Automatic Gemini fallback, (3) Failure logging to ai_failures table, (4) 3-failure escalation, (5) Quota exhaustion handling. Satisfies SC-5.1 through SC-5.4. Previous features: AI routing, deduplication, 13-message memory, tool inventory (ADHD Commander, Finance Manager, System Status).",
    "templateCredsSetupCompleted": true,
    "toolInventory": {
      "ADHD_Commander": "Task prioritization and focus guidance from Notion",
      "Finance_Manager": "Transaction logging and financial tracking",
      "System_Status": "Infrastructure health checks and system monitoring"
    },
    "fallbackConfig": {
      "primary": "ollama-qwen2.5:7b",
      "secondary": "gemini-2.5-flash-lite",
      "timeout": "30s",
      "escalationThreshold": 3
    }
  }
}
```

### Step 5: Deploy Updated Workflow

```bash
# On local machine, validate JSON syntax
cd /Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE
python3 -m json.tool workflow_supervisor_agent.json > /dev/null && echo "JSON is valid" || echo "JSON syntax error"

# Copy to EC2
scp -i ~/cyber-squire-ops/cyber-squire-ops.pem \
  workflow_supervisor_agent.json \
  ec2-user@54.234.155.244:/home/ec2-user/COREDIRECTIVE_ENGINE/

# SSH to EC2
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244

# Navigate to n8n workflows directory
cd /home/ec2-user/.n8n/

# Import workflow via n8n CLI (if available) or manual import via UI
# Manual import steps:
# 1. Open n8n UI: http://54.234.155.244:5678
# 2. Go to Workflows
# 3. Click "..." menu on "Telegram Supervisor Agent"
# 4. Select "Import from File"
# 5. Upload /home/ec2-user/COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json
# 6. Confirm overwrite
# 7. Activate workflow
```

## Post-Deployment Testing

### Test 1: Normal Operation (Ollama Healthy)
```bash
# Send test message via Telegram
# Message: "Hello"
# Expected: Normal response from Ollama, no fallback indicator
```

### Test 2: Ollama Failure Simulation
```bash
# SSH to EC2
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244

# Stop Ollama temporarily
docker stop ollama

# Send test message via Telegram
# Message: "What should I work on?"
# Expected: Response with "_via Gemini fallback_" footer

# Check logs
docker logs n8n --tail 50 | grep "AI_FALLBACK"

# Check database
docker exec -it postgresql psql -U n8n -d n8n -c "SELECT * FROM ai_failures ORDER BY timestamp DESC LIMIT 5;"

# Restart Ollama
docker start ollama
```

### Test 3: Escalation Trigger
```bash
# With Ollama stopped, send 3 messages within 10 minutes
# Message 1: "Test 1"
# Message 2: "Test 2"
# Message 3: "Test 3"
# Expected: Message 3 should include escalation warning

# Verify escalation
docker exec -it postgresql psql -U n8n -d n8n -c \
  "SELECT chat_id, COUNT(*) FROM ai_failures WHERE timestamp > NOW() - INTERVAL '10 minutes' GROUP BY chat_id;"
```

### Test 4: Gemini Response Quality
```bash
# With Ollama stopped, test routing accuracy
# Test messages:
# 1. "Check system health" (should mention System_Status tool or provide system info)
# 2. "What's on my plate?" (should mention ADHD_Commander or task context)
# 3. "I spent $50 on dinner" (should mention Finance_Manager or money tracking)
# 4. "Random gibberish asdfqwer" (should provide fallback orientation message)

# Compare responses with Ollama-generated responses (restart Ollama and re-test)
```

### Test 5: Recovery Verification
```bash
# Ensure Ollama is running
docker start ollama
docker ps | grep ollama

# Send test message
# Message: "Status check"
# Expected: Response WITHOUT "_via Gemini fallback_" footer

# Verify primary AI restored
docker logs n8n --tail 20 | grep -E "(OLLAMA|GEMINI)"
```

## Monitoring Setup

### Create Fallback Metrics Query
```sql
-- Save as fallback_metrics.sql
SELECT
  DATE_TRUNC('hour', timestamp) as hour,
  COUNT(*) FILTER (WHERE provider = 'ollama') as ollama_failures,
  COUNT(*) FILTER (WHERE provider = 'gemini') as gemini_failures,
  COUNT(*) as total_failures,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE provider = 'gemini') /
    NULLIF(COUNT(*), 0),
    2
  ) as gemini_usage_pct
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;
```

### Create Alert Query
```sql
-- Save as escalation_check.sql
SELECT
  chat_id,
  COUNT(*) as consecutive_failures,
  MAX(timestamp) as last_failure,
  STRING_AGG(DISTINCT failure_type, ', ') as failure_types
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '10 minutes'
  AND resolved = FALSE
GROUP BY chat_id
HAVING COUNT(*) >= 3
ORDER BY consecutive_failures DESC;
```

### Schedule Daily Report
```bash
# Add to crontab on EC2
crontab -e

# Add line:
0 9 * * * docker exec postgresql psql -U n8n -d n8n -f /home/ec2-user/fallback_metrics.sql > /home/ec2-user/daily_fallback_report.txt 2>&1
```

## Troubleshooting

### Issue: Gemini API 403 Forbidden
**Cause:** Invalid API key or API not enabled

**Fix:**
```bash
# Verify API key in .env
cat /home/ec2-user/COREDIRECTIVE_ENGINE/.env | grep GEMINI

# Test API key manually
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=YOUR_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"test"}]}]}'

# Enable Generative Language API:
# https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com
```

### Issue: Database Connection Failed
**Cause:** PostgreSQL credentials not configured in Code nodes

**Fix:**
1. Open n8n workflow editor
2. For each Code node with database queries, click node
3. Add PostgreSQL credential: Select "CD PostgreSQL"
4. Save workflow

### Issue: Fallback Not Triggering
**Cause:** Ollama timeout longer than expected

**Fix:**
```bash
# Check Ollama response time
time curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "Hello",
  "stream": false
}'

# If >30s, consider reducing n8n workflow timeout or Ollama parameters
```

### Issue: Escalation Spam
**Cause:** Threshold too low or failures not auto-resolving

**Fix:**
```sql
-- Check auto-resolve trigger
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname = 'trigger_auto_resolve_failures';

-- Manually resolve old failures
UPDATE ai_failures
SET resolved = TRUE, resolved_at = NOW()
WHERE timestamp < NOW() - INTERVAL '1 hour'
  AND resolved = FALSE;

-- Adjust escalation threshold in workflow (change from 3 to 5)
```

## Rollback Procedure

If critical issues occur:

```bash
# SSH to EC2
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244

# Restore backup
cd /home/ec2-user/COREDIRECTIVE_ENGINE
cp workflow_supervisor_agent_backup_*.json workflow_supervisor_agent.json

# Reimport via n8n UI (same steps as deployment)

# Drop ai_failures table
docker exec -it postgresql psql -U n8n -d n8n -c "DROP TABLE IF EXISTS ai_failures CASCADE;"

# Document rollback reason
cd /Users/et/cyber-squire-ops/.planning/phases/05-fallback-resilience
nano ROLLBACK.md
# Add: reason, timestamp, symptoms, lessons learned
```

## Success Validation

Phase 5 is considered complete when:

- [ ] SC-5.1: Ollama timeout triggers Gemini fallback (Test 2 passes)
- [ ] SC-5.2: Gemini response quality matches Ollama (Test 4 passes)
- [ ] SC-5.3: Fallback events logged to `ai_failures` table (Test 2 database check)
- [ ] SC-5.4: Escalation appears after 3 failures (Test 3 passes)
- [ ] All tests pass without manual intervention
- [ ] No errors in n8n execution logs for 24 hours
- [ ] Fallback metrics query returns valid data
- [ ] System recovers automatically when Ollama restored (Test 5 passes)

Document completion in `SUMMARY.md`.
