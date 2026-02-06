# Architecture Research: Telegram → n8n → Ollama Routing System

**Research Date:** 2026-02-04
**Project:** Cyber-Squire Operations - CoreDirective Automation Engine
**Scope:** Consolidate 30+ workflow JSONs into maintainable, scalable architecture

---

## Executive Summary

After analyzing the existing codebase and current n8n best practices, the recommendation is clear: **adopt a modular supervisor-agent architecture** with specialized sub-workflows, abandoning both the monolithic If-cascade pattern and the webhook-based router in favor of an AI-powered routing layer with LangChain tool integration.

**Key Findings:**
- Performance improves 40-60% with modular sub-workflows vs monolithic designs
- Switch nodes outperform If cascades for 3+ routes
- Global error workflows + node-level retries provide resilient operation
- PostgreSQL chat memory enables stateful conversations
- Credential references (not hardcoded tokens) are mandatory for security

---

## 1. Architecture Pattern Analysis

### Current State Assessment

**Existing Implementations Found:**

1. **workflow_master_router_v5.json** (Webhook + If Cascade)
   - Trigger: Webhook POST `/telegram-bot`
   - Routing: If → If → If → If cascade (4 commands)
   - Sub-workflows: Executes `Financial War Room` via Execute Workflow node
   - Credentials: HARDCODED Telegram bot token (security issue)
   - Logging: PostgreSQL `nuclear_event_log` table
   - Response: HTTP Request to Telegram API

2. **workflow_telegram_commander.json** (Telegram Trigger + LangChain Agent)
   - Trigger: Telegram Trigger node (native)
   - Routing: AI Agent with 6 LangChain tools
   - Features: Voice message support via Whisper STT
   - Memory: Buffer Window (20 messages, in-memory)
   - Credentials: Properly referenced via credential system
   - No sub-workflow calls - all tools are direct LangChain tool workflows

3. **workflow_supervisor_agent.json** (Hybrid Approach)
   - Trigger: Telegram Trigger node
   - Routing: AI Agent with 2 tool workflows
   - Memory: PostgreSQL Chat Memory (13 messages, persistent)
   - Sub-workflows: ADHD Commander, Finance Manager via LangChain tools
   - System Prompt: Consultative Authority framework
   - Credentials: Properly referenced

**Version Sprawl Issues:**
- 8 master_router variants (v3-v5, stable, original, nosecret, with_logging)
- 2 ADHD commander versions
- 2 12WY commander versions
- Inconsistent credential management across versions
- Hardcoded tokens in 8 workflow files (Telegram bot token exposed)

### Recommended Architecture: AI Supervisor with Modular Agents

```
┌─────────────────────────────────────────────────────────────────┐
│                      TELEGRAM INTERFACE                          │
│                  (Single Entry Point)                            │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  SUPERVISOR AGENT                                │
│  - Telegram Trigger node (native, not webhook)                  │
│  - Parse & Normalize Input (Code node)                          │
│  - AI Agent (LangChain with Ollama Qwen 2.5:7b)                │
│  - PostgreSQL Chat Memory (persistent, session-keyed)           │
│  - System Prompt: Consultative Authority + routing logic        │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                ┌────────┴────────┐
                │  Tool Registry  │
                └────────┬────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│ ADHD COMMANDER│ │FINANCE MANAGER│ │SECURITY SCAN  │
│               │ │               │ │               │
│ • Notion API  │ │ • Google      │ │ • Execute     │
│ • Ollama AI   │ │   Sheets      │ │   Command     │
│ • Postgres Log│ │ • Ollama AI   │ │ • Format      │
│               │ │ • Postgres Log│ │   Results     │
└───────────────┘ └───────────────┘ └───────────────┘
        │                │                │
        └────────────────┼────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              SHARED INFRASTRUCTURE                               │
│  - PostgreSQL (state, memory, logs)                             │
│  - Ollama (Qwen 2.5:7b local inference)                         │
│  - Telegram Bot API (via credentials)                           │
│  - External APIs (Notion, Google, etc.)                         │
└─────────────────────────────────────────────────────────────────┘
```

**Why This Pattern:**

✅ **Modularity:** Each agent is 5-10 nodes (optimal per n8n best practices)
✅ **Scalability:** Add new agents without touching supervisor code
✅ **Testability:** Each sub-workflow can be tested independently
✅ **Memory Efficiency:** Prevents heap overflow on large operations
✅ **AI-Powered Routing:** No manual If/Switch maintenance
✅ **State Persistence:** PostgreSQL chat memory survives restarts

---

## 2. Routing Pattern Comparison

### Pattern 1: If Node Cascade (Current: master_router_v5)

```javascript
Parse & Route (Code) → Is Focus? (If) → Is Money? (If) → Is Status? (If) → Is Help? (If) → Unknown
```

**Pros:**
- Simple to understand
- Explicit control flow
- No AI required

**Cons:**
- Brittle: Every new command requires workflow edit
- No natural language handling
- Cascading checks = sequential processing
- Difficult to add conditional logic (e.g., "money expense AWS")
- Visual clutter (4+ If nodes in a row)

**Performance:** O(n) where n = number of commands

### Pattern 2: Switch Node (Not Currently Used)

```javascript
Parse & Route (Code) → Switch (route field) → [focus, money, status, help, unknown]
```

**Pros:**
- Cleaner than If cascade (single node)
- Parallel output paths
- Easy to add routes

**Cons:**
- Still requires hardcoded route matching
- No natural language understanding
- Requires Code node preprocessing to normalize input

**Performance:** O(1) lookup after initial parsing

**When to Use:** 3+ distinct routes with deterministic logic (e.g., webhook event types)

### Pattern 3: Code-Based Router (Custom Logic)

```javascript
Code Node (contains full routing logic) → Dynamic outputs
```

**Pros:**
- Maximum flexibility
- Can implement complex logic
- Centralized routing rules

**Cons:**
- Black box (harder to debug)
- Requires JavaScript knowledge to maintain
- No visual flow representation
- Difficult to add routes without code changes

**Performance:** O(1) with good hashing

**When to Use:** Complex routing logic, external routing tables, dynamic route generation

### Pattern 4: AI Agent with LangChain Tools (RECOMMENDED)

```javascript
AI Agent → Tool Router (automatic) → [Tool 1, Tool 2, Tool 3, ...]
```

**Pros:**
- Natural language understanding ("show me money stuff" → Finance Manager)
- Zero code changes to add new tools
- Handles ambiguous requests ("what should I do?" → ADHD Commander)
- Conversational context awareness
- Self-documenting (tool descriptions)

**Cons:**
- Requires AI inference (latency ~1-3s with Ollama)
- Slightly higher resource usage
- Routing decisions not deterministic (can vary)

**Performance:** O(n) where n = number of tools (but n is typically small)

**When to Use:** User-facing conversational interfaces, complex intent detection

---

## 3. Component Boundaries & Responsibilities

### Supervisor Agent (Single Instance)

**Responsibility:** Orchestrate system, maintain conversation context, route requests

**Nodes:**
1. **Telegram Trigger** - Native listener (no webhook needed)
2. **Parse Input** - Normalize message/callback_query to standard format
3. **AI Agent** - LangChain agent with Ollama Qwen 2.5:7b
4. **PostgreSQL Chat Memory** - Session-keyed, 13-message window
5. **Format Output** - Truncate to Telegram limits (4096 chars)
6. **Send Response** - Telegram send message

**State:** Chat memory (PostgreSQL), no static data

**Triggers:** Telegram updates (messages, callback_query)

**Tools Registered:**
- ADHD Commander
- Finance Manager
- System Status
- Security Scan
- Create Task
- (Extensible - add more as needed)

### Sub-Workflow: ADHD Commander

**Responsibility:** Select highest-ROI task from Notion, reduce analysis paralysis

**Trigger:** Execute Workflow Trigger (called as LangChain tool)

**Data Flow:**
```
Input: { chatId, user, text }
↓
Notion API: Get incomplete tasks (Status != Done)
↓
Parse: Extract name, priority, due date
↓
Ollama: AI selects ONE task based on time of day, urgency, priority
↓
Format: Mission-style message with task, duration, motivation
↓
Output: { chatId, text (Markdown), selectedTask, duration }
↓
Telegram: Send mission + Log to PostgreSQL
```

**Nodes:** 9 total (within best practice range)

**State:** None (stateless execution)

**Environment Variables:** `NOTION_TASKS_DB_ID`

### Sub-Workflow: Finance Manager

**Responsibility:** Categorize and log financial transactions, show dashboard

**Trigger:** Execute Workflow Trigger

**Data Flow:**
```
Input: { text (e.g., "AWS $45 monthly"), chatId, user }
↓
Ollama: Extract type, category, vendor, amount
↓
Validate: Ensure category matches allowed list
↓
Google Sheets: Append to Ledger
↓
Read: Calculate totals (income, expense, debt paid)
↓
Format: Dashboard with net flow, debt progress
↓
Output: { chat_id, text (Markdown) }
↓
Telegram: Send dashboard
```

**Nodes:** 6 total

**State:** Google Sheets (external)

**Validation:** Category must match predefined lists (prevents data pollution)

### Sub-Workflow: System Status

**Responsibility:** Health check (Docker, memory, disk, load)

**Trigger:** Tool Workflow Input

**Data Flow:**
```
Input: (none required)
↓
Execute Command: Run system checks (docker ps, free -h, df -h, uptime)
↓
Format: Markdown code block with status emoji
↓
Output: { response: "**System Status Report**..." }
```

**Nodes:** 4 total (minimal)

**State:** None

### Sub-Workflow: Create Task

**Responsibility:** Parse task description, create in Notion

**Trigger:** Tool Workflow Input

**Data Flow:**
```
Input: { query: "Fix OAuth bug" } or { query: "{\"title\":\"...\",\"priority\":\"high\"}" }
↓
Parse: JSON or plain text → title, priority, dueDate
↓
Notion API: Create database page
↓
Format: Confirmation with Notion URL
↓
Output: { response: "✅ Task Created..." }
```

**Nodes:** 5 total

**State:** Notion database

---

## 4. Error Handling & Fallback Patterns

### Global Error Workflow (workflow_error_handler.json)

**Purpose:** Catch all unhandled errors across workflows

**Setup:**
1. Create dedicated workflow with Error Trigger node
2. In each production workflow: Settings → Error Workflow → Select handler
3. Handler formats error details and sends Telegram alert

**Current Implementation:**
```
Error Trigger → Format Error (Code) → Send Alert (HTTP to Telegram)
```

**Issues Found:**
- Hardcoded Telegram bot token (must use credential reference)
- Hardcoded chat_id (should use environment variable)

**Recommended Pattern:**

```javascript
// Error Trigger → Code Node
const err = $input.first().json;
const workflowName = err.workflow?.name || 'Unknown';
const errorMsg = err.execution?.error?.message || 'Unknown error';
const lastNode = err.execution?.lastNodeExecuted || 'Unknown';
const executionId = err.execution?.id || 'N/A';

const msg = `🔴 **WORKFLOW FAILURE**\n\n` +
  `**Workflow:** ${workflowName}\n` +
  `**Error:** ${errorMsg}\n` +
  `**Last Node:** ${lastNode}\n` +
  `**Execution ID:** ${executionId}\n` +
  `**Time:** ${new Date().toISOString()}`;

return {
  json: {
    chatId: $env.TELEGRAM_ADMIN_CHAT_ID, // From environment
    text: msg,
    parse_mode: 'Markdown'
  }
};
```

**Then:** Telegram node (using credential reference)

### Node-Level Error Handling

**Best Practice:** Enable "Continue on Fail" for non-critical operations

**Example - ADHD Commander:**
```
Ollama Task Selector → (if fails) → Format Fallback Message
```

**Retry Settings:**
- API calls to Ollama: 2 retries, 5s wait
- External APIs (Notion, Google Sheets): 3 retries, exponential backoff
- Telegram sends: 1 retry (fast fail to avoid duplicate messages)

### Circuit Breaker Pattern (Advanced)

**Use Case:** If Notion API is down, pause all Notion-dependent workflows

**Implementation:**
```
1. Track failures in PostgreSQL table (workflow_name, failure_count, last_failure)
2. Before calling Notion, check failure count
3. If count > 5 in last 5 minutes → Trigger fallback (e.g., log to local DB)
4. Send admin alert: "Notion circuit breaker triggered"
5. Auto-reset after 15 minutes
```

**Not Currently Implemented** - Future enhancement for production resilience

---

## 5. Sub-Workflow Communication Best Practices

### Data Passing via Execute Workflow Node

**Pattern:**
```javascript
// Parent workflow (Supervisor Agent uses LangChain Tool Workflow)
LangChain Tool: ADHD Commander
  - Tool passes: { chatId, user, text }
  - Tool receives: { response: "..." }
  - Agent integrates response into conversation
```

**Key Insight:** LangChain Tool Workflow nodes automatically handle input/output mapping

**For Non-LangChain Execute Workflow:**
```javascript
Execute Workflow Node
  - Source: "Database" (most reliable)
  - Workflow ID: Use workflow ID, not name (names can change)
  - Input data: Use expression {{ $json }}
```

### Shared State Management

**Option 1: PostgreSQL Tables (Recommended)**
```sql
-- Shared state table
CREATE TABLE workflow_state (
  session_id TEXT PRIMARY KEY,
  state_data JSONB,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Example: Parent writes
INSERT INTO workflow_state (session_id, state_data)
VALUES ('user_123', '{"current_task": "Lab Report"}');

-- Child reads
SELECT state_data FROM workflow_state WHERE session_id = 'user_123';
```

**Option 2: Environment Variables**
- Use for configuration (database IDs, API endpoints)
- NOT for session data (not dynamic)

**Option 3: Static Data (Workflow-Level)**
- Survives workflow executions
- Limited to single workflow (not shared)
- Use for counters, last-run timestamps

### Communication Patterns

**Synchronous (Current):**
```
Supervisor → Execute Workflow → Wait for Response → Continue
```
- Simple, guaranteed order
- Can block if sub-workflow is slow
- Best for user-facing operations

**Asynchronous (Future Enhancement):**
```
Supervisor → Webhook to Sub-Workflow → Continue
Sub-Workflow → Completes Later → Calls Back via Webhook
```
- Non-blocking
- Complex state management
- Best for background processing (e.g., video transcription)

---

## 6. Credential Management Patterns

### CRITICAL FINDING: 8 Workflows with Hardcoded Tokens

**Security Violations Found:**
```
Telegram Bot Token: REVOKED - stored in n8n credentials (credential ID: telegram-bot-main)
Files:
- workflow_master_router_v5.json (line 172)
- workflow_error_handler.json (line 25)
- workflow_financial_warroom.json (line 114)
- workflow_adhd_commander_v2.json
- workflow_master_router_original.json
- workflow_master_router_stable.json
- workflow_master_router_v4.json
- workflow_master_router_with_logging.json
```

**This token must be rotated immediately** (see CLAUDE.md)

### Correct Pattern: Credential References

**Good Example (workflow_telegram_commander.json):**
```json
{
  "credentials": {
    "telegramApi": {
      "id": "telegram-bot-main",
      "name": "Telegram Bot"
    }
  }
}
```

**How Credentials Work in n8n:**
1. Create credential in n8n UI or via API
2. n8n stores encrypted in PostgreSQL (AES-256 with `N8N_ENCRYPTION_KEY`)
3. Reference by ID in workflow JSON
4. At runtime, n8n decrypts and injects

**Credential Injection Script Analysis:**

File: `inject_credentials.sh`
- Reads `credentials_vault.json`
- POSTs to `${N8N_HOST}/api/v1/credentials`
- Uses `N8N_API_KEY` for authentication
- Supports: anthropic, github, google_oauth, gumroad, notion, perplexity

**Issue:** credentials_vault.json contains plaintext API keys
**Mitigation:** This file must be in `.gitignore` (already is) and encrypted at rest

### Environment Variables vs Credentials

**Use Credentials For:**
- API keys (Anthropic, GitHub, Notion, etc.)
- OAuth tokens (Google, Gumroad)
- Database passwords

**Use Environment Variables For:**
- Database IDs (Notion database ID)
- Telegram chat IDs
- Configuration (N8N_HOST, etc.)

**Pattern:**
```javascript
// In workflow JSON
"databaseId": {
  "__rl": true,
  "value": "={{ $env.NOTION_TASKS_DB_ID }}",
  "mode": "id"
}
```

### Rotation Strategy

**Every 90 Days (per CLAUDE.md):**
1. Generate new API key in service dashboard
2. Update `credentials_vault.json`
3. Run `./inject_credentials.sh` (will fail - credentials already exist)
4. Manually update in n8n UI or delete old credential and re-inject
5. Test workflows
6. Revoke old key

**Better Approach (Future):**
- Use n8n credential update API endpoint
- Script: `./rotate_credentials.sh <service_name>`

---

## 7. Build Order & Migration Strategy

### Phase 1: Foundation (Day 1)

**Goal:** Establish clean supervisor without sub-workflows

1. **Create Supervisor Base**
   - Start from `workflow_supervisor_agent.json` (cleanest current implementation)
   - Remove ADHD/Finance tools temporarily
   - Verify: Telegram → AI Agent → Response works
   - Test: "hello", "what time is it", simple Q&A

2. **Fix Credential Security**
   - Identify all workflows with hardcoded tokens
   - Create Telegram credential in n8n
   - Update Send nodes to use credential reference
   - Rotate Telegram bot token (old one is exposed)

3. **Setup Global Error Handler**
   - Fix hardcoded token in `workflow_error_handler.json`
   - Add `TELEGRAM_ADMIN_CHAT_ID` to environment
   - Link to supervisor workflow settings
   - Test: Force an error, verify alert received

**Validation:**
- Supervisor responds to basic messages
- No hardcoded credentials in active workflows
- Error handler sends alerts to admin

### Phase 2: Core Agents (Day 2)

**Goal:** Add essential sub-workflows as LangChain tools

4. **Deploy ADHD Commander**
   - Use `workflow_adhd_commander.json` (v1, not v2)
   - Ensure `NOTION_TASKS_DB_ID` is set
   - Test standalone: Trigger manually via n8n UI
   - Integrate: Add as LangChain tool to Supervisor

5. **Deploy Finance Manager**
   - Use `workflow_financial_warroom.json`
   - Replace `YOUR_SHEET_ID` with real Google Sheets ID
   - Fix hardcoded Telegram token (use credential)
   - Test: Send "/money AWS $45" via supervisor

6. **Deploy System Status**
   - Use `workflow_tool_system_status.json` (already clean)
   - Add as tool to supervisor
   - Test: "check system status"

**Validation:**
- "what should I focus on?" → ADHD Commander responds
- "paid AWS $67" → Finance Manager logs and shows dashboard
- "system status" → Health check runs

### Phase 3: Extended Tools (Day 3)

**Goal:** Add secondary workflows

7. **Deploy Create Task**
   - Use `workflow_tool_create_task.json`
   - Configure Notion credential
   - Test: "create task: fix OAuth bug, high priority"

8. **Deploy Security Scan**
   - Use `workflow_tool_security_scan.json`
   - Requires SSH access to run nmap/nuclei
   - Test: "scan 192.168.1.1" (in dev environment)

**Validation:**
- "remind me to call John tomorrow" → Task created
- "scan localhost" → Security report returned

### Phase 4: Consolidation (Day 4)

**Goal:** Archive old workflows, establish naming conventions

9. **Archive Obsolete Workflows**
   - Create `/COREDIRECTIVE_ENGINE/archive/` directory
   - Move all `*_v2`, `*_v3`, etc. to archive
   - Move all `*_stable`, `*_original`, `*_nosecret` to archive
   - Keep only canonical versions

10. **Naming Convention**
    ```
    workflow_supervisor_agent.json          # Main entry point
    workflow_agent_adhd_commander.json      # Sub-workflow agents
    workflow_agent_finance_manager.json
    workflow_agent_security_scan.json
    workflow_tool_system_status.json        # Utility tools
    workflow_tool_create_task.json
    workflow_system_error_handler.json      # System workflows
    ```

11. **Documentation**
    - Update README.md with new architecture diagram
    - Create DEPLOYMENT.md with step-by-step setup
    - Add TROUBLESHOOTING.md with common issues

**Validation:**
- Only 1 version of each workflow in production directory
- All workflows follow naming convention
- Documentation reflects new architecture

### Phase 5: Optimization (Day 5+)

**Future Enhancements:**

- **PostgreSQL Chat Memory Optimization:** Tune context window (currently 13 messages)
- **AI Model Swapping:** Add Gemini/Claude fallback for complex queries
- **Multi-Language Support:** Handle voice messages in multiple languages
- **Analytics Dashboard:** Track tool usage, response times, error rates
- **A/B Testing:** Compare AI routing vs manual routing performance

---

## 8. Quality Gates & Success Criteria

### Component Boundaries

✅ **Well-Defined Inputs/Outputs**
- Each sub-workflow has clear contract (Tool Workflow Input/Output nodes)
- Supervisor passes minimal data (chatId, user, text)
- Responses are formatted consistently (Markdown, <4096 chars)

✅ **Single Responsibility**
- ADHD Commander: Task selection only
- Finance Manager: Financial logging only
- Each workflow does ONE thing well

✅ **No Hidden Dependencies**
- All external services explicitly declared (credentials, environment vars)
- No shared static data between workflows
- State stored in PostgreSQL (explicit, visible)

### Data Flow Explicit

✅ **Traceable**
- PostgreSQL logs all events (nuclear_event_log, commander_log)
- n8n execution history shows full data path
- Chat memory stored in `chat_memory` table (inspectable)

✅ **Debuggable**
- Each Code node has clear variable names
- Error messages include context (workflow name, execution ID)
- Test data can be injected at any workflow entry point

### Build Order Implications

✅ **Dependencies Clear**
1. Supervisor can run standalone (no sub-workflows)
2. Sub-workflows can be tested independently (Execute Workflow Trigger)
3. Tools added incrementally (1 tool = 1 deployment)

✅ **Rollback Safe**
- Deactivating a tool doesn't break supervisor (AI just won't call it)
- Old workflows archived, not deleted (can restore if needed)
- Credentials managed separately (rotate without workflow changes)

---

## 9. Recommendations Summary

### Architecture Decision: Modular Supervisor-Agent

**Adopt:** `workflow_supervisor_agent.json` pattern as canonical architecture

**Rationale:**
1. **Performance:** 40-60% faster than monolithic (per industry research)
2. **Maintainability:** Add tools without touching supervisor code
3. **AI-Powered:** Natural language routing (no If/Switch maintenance)
4. **State Management:** PostgreSQL chat memory (persistent, session-aware)
5. **Scalability:** Each agent is 5-10 nodes (optimal per n8n best practices)

### Routing Pattern: AI Agent with LangChain Tools

**Replace:** If-cascade and webhook routers
**With:** LangChain AI Agent + Tool Workflow nodes

**Rationale:**
- Natural language understanding
- Self-documenting (tool descriptions)
- Zero-code tool addition
- Conversational context awareness

### Error Handling: Global + Node-Level

**Implement:**
1. Global error workflow (all workflows link to it)
2. Node-level retries (APIs: 3 retries, exponential backoff)
3. Circuit breaker for external services (future)

### Credential Management: Zero Hardcoded Tokens

**Action Required:**
1. Rotate Telegram bot token (currently exposed in 8 files)
2. Migrate all HTTP Telegram calls to Telegram node (with credential)
3. Move chat IDs to environment variables

### Sub-Workflow Communication: Tool Workflow Pattern

**Standard:**
- Parent: LangChain Tool Workflow node
- Child: Tool Workflow Input → Process → Tool Workflow Output
- State: PostgreSQL for persistence, environment vars for config

### State Management: PostgreSQL-Centric

**Pattern:**
- Chat memory: `chat_memory` table (LangChain PostgreSQL Memory node)
- Event logs: Custom tables (`nuclear_event_log`, `commander_log`)
- Shared state: JSONB column in `workflow_state` table

---

## 10. References & Sources

### n8n Best Practices (2026)

1. [How to Build AI Agents with n8n: Complete 2026 Guide](https://strapi.io/blog/build-ai-agents-n8n)
2. [Seven N8N Workflow Best Practices for 2026](https://michaelitoback.com/n8n-workflow-best-practices/)
3. [Sub-workflows | n8n Docs](https://docs.n8n.io/flow-logic/subworkflows/)
4. [What is Modular Automation Design in n8n? A Guide to Scalable Workflows](https://hussamkazim.com/what-is-modular-automation-design-in-n8n-guide/)
5. [Multi-agent system: Frameworks & step-by-step tutorial – n8n Blog](https://blog.n8n.io/multi-agent-systems/)
6. [n8n Execute Sub-workflow Node - Tutorial, Examples, Best Practices](https://logicworkflow.com/nodes/execute-sub-workflow-node/)

### Routing Patterns

7. [Switch | n8n Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.switch/)
8. [n8n If & Switch: Conditional Routing Guide](https://n8n.blog/n8n-if-switch-conditional-routing-guide/)
9. [The n8n IF Node and Switch Node – Autom8 This](https://autom8this.com/the-n8n-if-node-and-switch-node/)

### Error Handling

10. [Error handling | n8n Docs](https://docs.n8n.io/flow-logic/error-handling/)
11. [Stop Silent Failures: n8n Error Handling System](https://nextgrowth.ai/n8n-workflow-error-alerts-guide/)
12. [Advanced n8n Error Handling and Recovery Strategies](https://www.wednesday.is/writing-articles/advanced-n8n-error-handling-and-recovery-strategies)
13. [Error handling patterns for production n8n workflows | WotAI](https://wotai.co/blog/error-handling-patterns-production-workflows)
14. [5 n8n Error Handling Techniques for a Resilient Automation Workflow](https://www.aifire.co/p/5-n8n-error-handling-techniques-for-a-resilient-automation-workflow)

### State Management

15. [Sub-workflows | n8n Docs](https://docs.n8n.io/flow-logic/subworkflows/)
16. [State management system for long-running workflows](https://n8n.io/workflows/6269-state-management-system-for-long-running-workflows-with-wait-nodes/)
17. [How can I pass some values from one workflow to another (n8n)](https://community.n8n.io/t/how-can-i-pass-some-values-from-one-workflow-to-another-n8n/102184)

### Codebase Files Analyzed

18. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_master_router_v5.json`
19. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_telegram_commander.json`
20. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json`
21. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_error_handler.json`
22. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_adhd_commander.json`
23. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_financial_warroom.json`
24. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_tool_system_status.json`
25. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/workflow_tool_create_task.json`
26. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/README.md`
27. `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/inject_credentials.sh`

---

## Appendix A: Workflow Inventory

**Production-Ready (Keep):**
- workflow_supervisor_agent.json ⭐ (Canonical supervisor)
- workflow_adhd_commander.json (v1, clean)
- workflow_financial_warroom.json (needs token fix)
- workflow_tool_system_status.json
- workflow_tool_create_task.json
- workflow_tool_security_scan.json
- workflow_error_handler.json (needs token fix)

**Archive (Version Sprawl):**
- workflow_master_router.json
- workflow_master_router_v3.json
- workflow_master_router_v4.json
- workflow_master_router_v5.json
- workflow_master_router_stable.json
- workflow_master_router_original.json
- workflow_master_router_nosecret.json
- workflow_master_router_with_logging.json
- workflow_adhd_commander_v2.json
- workflow_12wy_commander.json
- workflow_12wy_commander_v2.json

**Special Purpose (Review Need):**
- workflow_api_healthcheck.json (useful for monitoring)
- workflow_notion_task_manager.json (may duplicate ADHD Commander)
- workflow_gumroad_solvency.json (specific business logic)
- workflow_youtube_factory.json (content pipeline)
- workflow_operation_nuclear.json (lead generation)
- workflow_ai_router.json (may be superseded by supervisor)

---

## Appendix B: PostgreSQL Schema Requirements

**Current Tables (Inferred from Workflows):**

```sql
-- Event logging (workflow_master_router_v5)
CREATE TABLE nuclear_event_log (
  id SERIAL PRIMARY KEY,
  raw_message TEXT,
  chat_id TEXT,
  command TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Chat memory (workflow_supervisor_agent)
CREATE TABLE chat_memory (
  session_id TEXT,
  message_type TEXT, -- 'human' or 'ai'
  content TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Commander log (workflow_adhd_commander)
CREATE TABLE commander_log (
  id SERIAL PRIMARY KEY,
  event_type TEXT,
  task_name TEXT,
  duration_minutes INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Recommended Additions:**

```sql
-- Shared state management
CREATE TABLE workflow_state (
  session_id TEXT PRIMARY KEY,
  state_data JSONB,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Error tracking (for circuit breaker)
CREATE TABLE workflow_errors (
  id SERIAL PRIMARY KEY,
  workflow_name TEXT,
  error_message TEXT,
  error_count INTEGER DEFAULT 1,
  last_failure TIMESTAMP DEFAULT NOW(),
  circuit_open BOOLEAN DEFAULT FALSE
);

-- Tool usage analytics
CREATE TABLE tool_usage (
  id SERIAL PRIMARY KEY,
  tool_name TEXT,
  user_id TEXT,
  execution_time_ms INTEGER,
  success BOOLEAN,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

**End of Architecture Research**
**Status:** Ready for implementation
**Next Step:** Proceed to Phase 1 (Foundation) of build order
