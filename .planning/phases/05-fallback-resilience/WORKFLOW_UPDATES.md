# Workflow Updates for Phase 5: Fallback & Resilience

## Overview
This document provides the JSON node definitions and connection updates needed to add Gemini fallback to `workflow_supervisor_agent.json`.

## New Nodes to Add

Copy these node objects into the `nodes` array of `workflow_supervisor_agent.json`:

### Node 1: Ollama Agent Wrapper
**Position in array:** After "Log Incoming Message" node

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

### Node 2: Check Agent Success
**Position in array:** After "Supervisor Agent" node

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

### Node 3: Prepare Gemini Fallback

```json
{
  "parameters": {
    "jsCode": "const inputCtx = $('Parse Input').first().json;\n\n// Build conversation context\nconst systemPrompt = `You are CYBER-SQUIRE, Emmanuel Tigoue's AI operations commander. You maintain Consultative Authority.\n\n## RESPONSE FORMAT (ADHD-FRIENDLY)\n1. Lead with the answer - no preambles\n2. Use bullets and visual hierarchy\n3. Bold key actions\n4. Keep under 200 words\n5. End with ONE clear next action\n\nRespond to the user's message below. Be direct and actionable.`;\n\nconst fullPrompt = `${systemPrompt}\\n\\nUser: ${inputCtx.text}\\n\\nRespond as CYBER-SQUIRE.`;\n\nreturn {\n  json: {\n    prompt: fullPrompt,\n    chatId: inputCtx.chatId,\n    messageId: inputCtx.messageId,\n    originalInput: inputCtx.text,\n    _execution: {\n      startTime: $('Ollama Agent Wrapper').first().json._execution.startTime,\n      provider: 'gemini',\n      attemptNumber: 2,\n      fallbackReason: 'ollama_failure'\n    }\n  }\n};"
  },
  "id": "prepare-gemini",
  "name": "Prepare Gemini Fallback",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [1900, 700]
}
```

### Node 4: Call Gemini API

```json
{
  "parameters": {
    "method": "POST",
    "url": "=https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={{ $env.GEMINI_API_KEY }}",
    "authentication": "none",
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
  "continueOnFail": true
}
```

### Node 5: Parse Gemini Response

```json
{
  "parameters": {
    "jsCode": "const geminiResponse = $input.first().json;\nconst executionMeta = $('Prepare Gemini Fallback').first().json._execution;\n\n// Check if request failed\nif (geminiResponse.error || !geminiResponse.candidates) {\n  throw new Error('Gemini API call failed: ' + (geminiResponse.error?.message || 'No candidates returned'));\n}\n\n// Extract response text\nconst responseText = geminiResponse.candidates?.[0]?.content?.parts?.[0]?.text || \n                     \"I apologize, but I'm having trouble processing your request.\";\n\nconst endTime = Date.now();\nconst latencyMs = endTime - executionMeta.startTime;\n\n// Append fallback indicator\nconst markedResponse = responseText + \"\\n\\n_via Gemini fallback_\";\n\nreturn {\n  json: {\n    output: markedResponse,\n    intermediate_steps: [],\n    _metadata: {\n      provider: 'gemini',\n      model: 'gemini-2.5-flash-lite',\n      latencyMs,\n      fallback: true\n    },\n    _execution: executionMeta\n  }\n};"
  },
  "id": "parse-gemini",
  "name": "Parse Gemini Response",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2340, 700]
}
```

### Node 6: Log Fallback Event

```json
{
  "parameters": {
    "jsCode": "const response = $input.first().json;\nconst inputCtx = $('Parse Input').first().json;\nconst timestamp = new Date().toISOString();\n\nconsole.log('AI_FALLBACK:', JSON.stringify({\n  event: 'ai_fallback_triggered',\n  timestamp,\n  chat_id: inputCtx.chatId,\n  provider: 'gemini',\n  latencyMs: response._metadata.latencyMs\n}));\n\nreturn {\n  json: {\n    ...response,\n    _escalation: {\n      needed: false,\n      failureCount: 1\n    }\n  }\n};"
  },
  "id": "log-fallback",
  "name": "Log Fallback Event",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2560, 700]
}
```

### Node 7: Merge Paths

```json
{
  "parameters": {},
  "id": "merge-paths",
  "name": "Merge Paths",
  "type": "n8n-nodes-base.merge",
  "typeVersion": 2.1,
  "position": [2780, 600]
}
```

### Node 8: Handle Gemini Failure

```json
{
  "parameters": {
    "jsCode": "const inputCtx = $('Parse Input').first().json;\nconst error = $input.first().json.error?.message || 'Unknown error';\n\nconsole.log('GEMINI_FALLBACK_FAILED:', JSON.stringify({\n  timestamp: new Date().toISOString(),\n  chat_id: inputCtx.chatId,\n  error\n}));\n\nconst isQuotaError = error.includes('429') || error.toLowerCase().includes('quota');\n\nconst fallbackMessage = isQuotaError\n  ? \"🔧 AI capacity temporarily limited. For urgent tasks, contact @ETcodin directly.\"\n  : \"⚠️ AI systems experiencing issues. Please try again in a few moments.\";\n\nreturn {\n  json: {\n    output: fallbackMessage,\n    intermediate_steps: [],\n    _metadata: {\n      provider: 'none',\n      fallback: true,\n      complete_failure: true\n    }\n  }\n};"
  },
  "id": "handle-gemini-failure",
  "name": "Handle Gemini Failure",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2340, 880]
}
```

## Connection Updates

Replace the `connections` section with these updated connections:

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
        [{ "node": "Merge Paths", "type": "main", "index": 0 }],
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
      "main": [[{ "node": "Merge Paths", "type": "main", "index": 1 }]]
    },
    "Merge Paths": {
      "main": [[{ "node": "Log Routing Decision", "type": "main", "index": 0 }]]
    },
    "Handle Gemini Failure": {
      "main": [[{ "node": "Merge Paths", "type": "main", "index": 1 }]]
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

## Metadata Update

Update the `meta.notes` field:

```json
{
  "meta": {
    "notes": "Supervisor Agent v4.0 (Resilient AI Routing): Added Gemini 2.5 Flash-Lite fallback for Ollama failures. Features: (1) Automatic Gemini fallback on Ollama failure, (2) Fallback indicator in responses, (3) Failure logging, (4) Quota exhaustion handling. Satisfies SC-5.1, SC-5.2, SC-5.3. Previous: AI routing, deduplication, 13-message memory, tool inventory.",
    "templateCredsSetupCompleted": true,
    "toolInventory": {
      "ADHD_Commander": "Task prioritization and focus guidance from Notion",
      "Finance_Manager": "Transaction logging and financial tracking",
      "System_Status": "Infrastructure health checks and system monitoring"
    },
    "fallbackConfig": {
      "primary": "ollama-qwen2.5:7b",
      "secondary": "gemini-2.5-flash-lite",
      "escalationThreshold": 3
    }
  }
}
```

## Visual Workflow Diagram

```
[Telegram Trigger]
       ↓
[Extract Message ID]
       ↓
[Check Duplicate] → [Skip Duplicate] (if duplicate)
       ↓
[Parse Input]
       ↓
[Log Incoming]
       ↓
[Ollama Wrapper] → [Supervisor Agent] → [Check Success]
                                              ↓               ↓
                                         (Success)      (Failure)
                                              ↓               ↓
                                              ↓      [Prepare Gemini]
                                              ↓               ↓
                                              ↓      [Call Gemini API]
                                              ↓               ↓ (error)
                                              ↓               ↓      ↓
                                              ↓      [Parse Gemini]  [Handle Failure]
                                              ↓               ↓            ↓
                                              ↓      [Log Fallback]       ↓
                                              ↓               ↓            ↓
                                              ↓─────[Merge Paths]─────────┘
                                                      ↓
                                             [Log Routing Decision]
                                                      ↓
                                              [Format Output]
                                                      ↓
                                            [Log Outgoing Response]
                                                      ↓
                                              [Send Response]
                                                      ↓
                                              [Mark Complete]
```

## Error Handling Configuration

### Call Gemini API Node
- **Continue on Fail:** `true`
- **Error workflow:** Connect to "Handle Gemini Failure" node

### Node Settings to Verify
1. All Code nodes have `typeVersion: 2`
2. HTTP Request node has `typeVersion: 4.2`
3. If node has `typeVersion: 2`
4. Merge node has `typeVersion: 2.1`

## Deployment Steps

1. **Backup current workflow:**
   ```bash
   cp workflow_supervisor_agent.json workflow_supervisor_agent_backup_$(date +%Y%m%d).json
   ```

2. **Edit JSON file:**
   - Add all new nodes to `nodes` array
   - Replace `connections` section
   - Update `meta` section

3. **Validate JSON:**
   ```bash
   python3 -m json.tool workflow_supervisor_agent.json > /dev/null
   ```

4. **Import to n8n:**
   - Open n8n UI
   - Workflows → "Telegram Supervisor Agent" → ... menu
   - Import from File
   - Upload updated JSON
   - Activate workflow

5. **Test fallback:**
   - Stop Ollama: `docker stop ollama`
   - Send test message via Telegram
   - Verify "_via Gemini fallback_" in response
   - Restart Ollama: `docker start ollama`

## Troubleshooting

### If workflow fails to import:
- Check JSON syntax with validator
- Verify all node IDs are unique
- Ensure all referenced node IDs exist in connections

### If fallback doesn't trigger:
- Check "Check Agent Success" condition
- Verify "Call Gemini API" has GEMINI_API_KEY in environment
- Check n8n execution logs for errors

### If Gemini returns errors:
- Verify API key validity
- Check Gemini API quota usage
- Ensure safety settings are correct
