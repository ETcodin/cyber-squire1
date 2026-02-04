# Common Pitfalls: Telegram + n8n + Local LLM Systems

**Project Context:** Budget-constrained (free AI only), ADHD user, health constraints, security professional

**Last Updated:** 2026-02-04

---

## 1. Ollama Timeout & Memory Issues

### Problem: 5-Minute Hard Timeout
**Symptom:** n8n's Ollama Chat Model node throws timeout errors after exactly 5 minutes (300,000ms), even for legitimate long-running requests.

**Root Cause:**
- The Ollama node has a hardcoded 5-minute timeout in n8n
- Setting `keep_alive` parameters (50m, -1m) in the node has **no effect** on the timeout
- HTTPS connections to Ollama exacerbate this, with some responses taking 28+ minutes

**Impact:**
- Complex reasoning tasks fail mid-completion
- Multi-turn conversations with large context windows time out
- No graceful degradation - just hard failure

**Prevention:**
- **Phase: Design** - Architect workflows to break long LLM tasks into smaller chunks (<5 min each)
- **Phase: Implementation** - Use HTTP (not HTTPS) for n8n→Ollama connections when on same host
- **Phase: Testing** - Load test with realistic context windows before deploying

**Actionable Workaround:**
```javascript
// In n8n Code node before Ollama call
// Break prompt into chunks with intermediate summaries
const maxTokensPerChunk = 4000; // Adjust based on model speed
if (estimatedTokens > maxTokensPerChunk) {
  // Split and process sequentially
}
```

**References:**
- [Ollama chat Node has limited the 5 mins timeout](https://community.n8n.io/t/ollama-chat-node-has-limited-the-5-mins-timeout/43621)
- [Ollama taking so long to respond](https://community.n8n.io/t/ollama-taking-so-long-to-respond/216166)

---

### Problem: Model Unloading Between Requests
**Symptom:** First request after idle period takes 30+ seconds due to model reload

**Root Cause:**
- Ollama unloads models after 5 minutes of inactivity by default
- Each reload for a 7B model takes 10-30 seconds depending on disk speed
- In Docker containers, memory limits can trigger aggressive unloading

**Impact:**
- User frustration during "activation paralysis" moments (critical for ADHD workflow)
- Timeouts on webhook responses to Telegram (expects response in <60s)
- Cascading failures when multiple requests queue during reload

**Prevention:**
- **Phase: Deployment** - Set `OLLAMA_KEEP_ALIVE=-1` environment variable (keeps models in memory indefinitely)
- **Phase: Deployment** - Allocate sufficient Docker memory (7B model = ~8GB RAM minimum)
- **Phase: Monitoring** - Track cold-start metrics separately from warm-start

**Actionable Configuration:**
```yaml
# docker-compose.yml
services:
  ollama:
    environment:
      - OLLAMA_KEEP_ALIVE=24h  # Or -1 for infinite
    deploy:
      resources:
        limits:
          memory: 10G  # Buffer above model size
```

**References:**
- [FAQ - Ollama](https://docs.ollama.com/faq)
- [Preventing Model Swapping In Ollama](https://blog.gopenai.com/preventing-model-swapping-in-ollama-a-guide-to-persistent-loading-f81f1dfb858d)

---

### Problem: Concurrent Request Queueing
**Symptom:** Requests freeze with no error when multiple users/workflows hit Ollama simultaneously

**Root Cause:**
- Ollama loads only one model at a time
- If insufficient memory to load a second model, ALL new requests queue silently
- No queue depth limits - requests can wait indefinitely

**Impact:**
- Complete system stall during high usage
- No feedback to user that request is queued
- Memory exhaustion if queue grows unbounded

**Prevention:**
- **Phase: Design** - Implement request queueing at n8n level with timeout/rejection
- **Phase: Monitoring** - Alert when Ollama response time >10s (indicates queueing)
- **Phase: Capacity Planning** - Budget for 2x peak concurrent LLM requests in memory

**Actionable Mitigation:**
```javascript
// n8n Code node before Ollama call
const queueDepth = await checkOllamaQueue(); // Custom endpoint
if (queueDepth > 3) {
  return { error: "System busy, try again in 30s" };
}
```

**References:**
- [Using Ollama/Docker to deploy your LLMs for GPU memory management](https://architpande888.medium.com/using-ollama-docker-to-deploy-your-llms-for-gpu-memory-management-04a1818b1a5f)

---

## 2. Telegram Webhook Reliability

### Problem: Silent Webhook Failures
**Symptom:** Bot "Waiting for trigger events" indefinitely, no errors in logs, no executions triggered

**Root Cause:**
- n8n generates incorrect webhook URL when behind reverse proxy
- Telegram silently rejects webhook without notifying n8n
- Single webhook per bot means dev/prod conflicts overwrite each other

**Impact:**
- Complete bot unavailability with no visibility
- Users assume bot is broken, lose trust
- Debugging requires manual Telegram API calls to check webhook status

**Prevention:**
- **Phase: Deployment** - Set `WEBHOOK_URL` env var to public HTTPS URL (not internal Docker hostname)
- **Phase: Testing** - Verify webhook with `curl https://api.telegram.org/bot{TOKEN}/getWebhookInfo`
- **Phase: Operations** - Use separate Telegram bots for dev/staging/prod (avoid webhook conflicts)

**Actionable Validation:**
```bash
# Add to deployment script
curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getWebhookInfo" \
  | jq -r '.result.url' \
  | grep -q "^https://${EXPECTED_DOMAIN}" \
  || echo "ERROR: Webhook misconfigured!"
```

**References:**
- [Telegram Trigger webhook stops receiving messages](https://community.n8n.io/t/telegram-trigger-webhook-stops-receiving-messages/239239)
- [Telegram Trigger node common issues](https://docs.n8n.io/integrations/builtin/trigger-nodes/n8n-nodes-base.telegramtrigger/common-issues/)

---

### Problem: HTTPS Requirement Breaks Cloudflare Tunnel
**Symptom:** "Bad Request: bad webhook: An HTTPS URL must be provided"

**Root Cause:**
- Telegram requires HTTPS for webhooks
- Cloudflare Tunnel provides HTTPS, but URL must be properly configured in `WEBHOOK_URL`
- Internal Docker networking uses HTTP, causing mismatch

**Impact:**
- Cannot use convenient Cloudflare Tunnel without extra configuration
- Development environments need SSL certificates or tunneling tools

**Prevention:**
- **Phase: Infrastructure** - Set `WEBHOOK_URL=https://your-tunnel-domain.com` (not `http://localhost`)
- **Phase: Infrastructure** - Configure Cloudflare Tunnel to route to correct internal port
- **Phase: Testing** - Use `ngrok` or `cloudflared` for local development webhooks

**Actionable Configuration:**
```bash
# .env for n8n
WEBHOOK_URL=https://your-tunnel.trycloudflare.com
N8N_PROTOCOL=https
N8N_HOST=your-tunnel.trycloudflare.com
```

**References:**
- [Cloudflare Tunnel - Telegram Webhook not responding](https://community.n8n.io/t/cloudflare-tunnel-telegram-webhook-not-responding/61892)
- [Fixing n8n Webhook Problems](https://www.tva.sg/fixing-n8n-webhook-problems-the-complete-troubleshooting-guide-for-self-hosted-instances/)

---

### Problem: Webhook Stops Receiving After Period of Inactivity
**Symptom:** Previously working bot stops responding after hours/days without traffic

**Root Cause:**
- Reverse proxy (nginx, Cloudflare) closes idle connections
- n8n doesn't detect connection drop and doesn't re-register webhook
- Telegram's webhook remains registered but points to dead connection

**Impact:**
- Intermittent failures with no pattern
- Requires manual workflow reactivation to fix
- Erodes user confidence in system reliability

**Prevention:**
- **Phase: Infrastructure** - Configure reverse proxy keepalive settings
- **Phase: Monitoring** - Implement webhook health check (test message every 15 min)
- **Phase: Operations** - Auto-restart workflow daily (forces webhook re-registration)

**Actionable Monitoring:**
```javascript
// n8n scheduled workflow (every 15 min)
const webhookInfo = await fetch(`https://api.telegram.org/bot${token}/getWebhookInfo`);
const data = await webhookInfo.json();
if (!data.result.url.includes(expectedDomain)) {
  // Alert ops + force workflow restart
}
```

**References:**
- [Telegram Trigger webhook stops receiving messages](https://community.n8n.io/t/telegram-trigger-webhook-stops-receiving-messages/239239)

---

## 3. Voice Transcription Failures

### Problem: Telegram .oga Format Rejected by Whisper
**Symptom:** Voice messages from Telegram fail transcription with "unsupported format" error

**Root Cause:**
- Telegram sends voice as .oga (Ogg Vorbis Audio)
- OpenAI Whisper API expects .mp3, .mp4, .wav, .webm
- Even renaming .oga → .ogg fails due to codec mismatch

**Impact:**
- Voice feature completely broken for primary use case
- Users fall back to typing (bad for ADHD activation energy)

**Prevention:**
- **Phase: Design** - Plan for audio transcoding in workflow
- **Phase: Implementation** - Use `ffmpeg` to convert .oga → .mp3 before Whisper
- **Phase: Testing** - Test with actual Telegram voice messages, not uploaded files

**Actionable Conversion:**
```javascript
// n8n Execute Command node
const inputFile = $binary.data.fileName;
const outputFile = inputFile.replace('.oga', '.mp3');
const cmd = `ffmpeg -i ${inputFile} -codec:a libmp3lame ${outputFile}`;
// Return binary data from outputFile
```

**Alternative:** Use Groq Whisper API (supports more formats) or local Whisper model via Ollama

**References:**
- [Voice messages transcribe fine — but uploaded audio files don't](https://community.n8n.io/t/voice-messages-transcribe-fine-but-uploaded-audio-files-don-t-even-with-corrected-mime/134761)
- [Trouble sending audio from Telegram to Replicate API](https://community.n8n.io/t/trouble-sending-audio-from-telegram-to-replicate-api/22430)

---

### Problem: Transcription Exists But AI Agent Throws "No Prompt Specified"
**Symptom:** Whisper transcribes successfully, but AI Agent node fails with "No prompt specified"

**Root Cause:**
- Transcription result not correctly passed to AI Agent's input
- Data mapping between nodes loses the transcription text
- AI Agent expects text in specific field name

**Impact:**
- Voice workflow breaks at final step (most frustrating for user)
- Debugging requires understanding n8n's data structure

**Prevention:**
- **Phase: Implementation** - Explicitly map transcription output to AI Agent input field
- **Phase: Testing** - Use "Execute Node" to inspect exact data structure between nodes
- **Phase: Documentation** - Document expected data shape for each node

**Actionable Mapping:**
```javascript
// n8n Code node between Whisper and AI Agent
return {
  json: {
    chatInput: $('Whisper').item.json.text,  // Explicit mapping
    sessionId: $('Telegram Trigger').item.json.message.chat.id
  }
};
```

**References:**
- [AI Agent node throws a "No prompt specified" error](https://community.n8n.io/t/im-building-a-telegram-chatbot-in-n8n-that-uses-openai-to-process-both-text-and-voice-messages-text-messages-work-fine-but-for-voice-messages-the-ai-agent-node-throws-a-no-prompt-specified-error-even-though-the-transcription-exists/104129)

---

## 4. LLM Hallucination in Routing Decisions

### Problem: Non-Deterministic Routing Breaks Critical Paths
**Symptom:** LLM routes identical requests to different workflows randomly (e.g., "buy bitcoin" → financial tracker OR crypto news)

**Root Cause:**
- LLM-based routing uses probabilistic generation
- No grounding/validation of routing decision
- Temperature >0 introduces randomness

**Impact:**
- Financial transactions routed to wrong workflow (catastrophic)
- User commands execute unpredictably
- No audit trail of why routing decision was made

**Prevention:**
- **Phase: Design** - Use LLM to extract intent, hard-coded Switch node for routing
- **Phase: Design** - Implement state machine pattern: LLM as data processor, not decision maker
- **Phase: Validation** - Use n8n's Eval node to test routing against ground truth dataset

**Actionable Pattern:**
```javascript
// WRONG: LLM decides route directly
LLM: "Based on user message, route to: 'financial_tracker'"
→ Switch node routes based on LLM output

// RIGHT: LLM extracts structured data, logic decides route
LLM: Extract { intent: "crypto_purchase", amount: 100, asset: "BTC" }
→ Switch node checks intent === "crypto_purchase" && amount > 0
→ Route to financial_tracker
```

**References:**
- [Iterations, hallucinations, and lessons learned](https://blog.n8n.io/iterations-hallucinations-and-lessons-learned-rebuilding-our-ai-assistant-on-n8n/)
- [How to build deterministic agentic AI with state machines in n8n](https://blog.logrocket.com/deterministic-agentic-ai-with-state-machines/)

---

### Problem: Hallucinated Tool Calls Execute Invalid Actions
**Symptom:** AI Agent generates tool parameters that don't match actual API schema, causing downstream errors

**Root Cause:**
- LLM invents plausible-looking but incorrect parameter names/values
- No schema validation before tool execution
- Error messages from failed tool call not fed back to LLM for retry

**Impact:**
- Database writes with wrong field names fail silently
- API calls return 400 errors that cascade through workflow
- User receives "something went wrong" with no actionable info

**Prevention:**
- **Phase: Implementation** - Use n8n's OpenAPI/JSON Schema tool definitions (not free-text descriptions)
- **Phase: Implementation** - Add validation node before tool execution
- **Phase: Error Handling** - Implement retry loop with error context fed back to LLM

**Actionable Validation:**
```javascript
// n8n Code node before database write
const schema = {
  task_title: 'string',
  due_date: 'ISO8601',
  priority: ['low', 'medium', 'high']
};

const errors = validateAgainstSchema($json, schema);
if (errors.length > 0) {
  return {
    error: errors,
    llmFeedback: "Fix these validation errors and try again"
  };
}
```

**References:**
- [How to stop your AI agents from hallucinating: A guide to n8n's Eval Node](https://blog.logrocket.com/stop-your-ai-agents-from-hallucinating-n8n/)

---

## 5. Credential Exposure in Workflow Exports

### Problem: API Keys in HTTP Request Node Headers
**Symptom:** Exported workflow JSON contains `Authorization: Bearer sk-...` in plain text

**Root Cause:**
- Developers paste cURL commands directly into HTTP Request node
- API tokens embedded in header configuration instead of using n8n credentials
- Export includes all node configuration, including headers

**Impact:**
- **CATASTROPHIC** for security professional reputation
- API tokens leaked when sharing workflows (GitHub, community, teammates)
- No way to rotate leaked credentials without breaking all workflows

**Prevention:**
- **Phase: Implementation** - ALWAYS use n8n Credentials for authentication, NEVER hardcode in nodes
- **Phase: Code Review** - Grep exported JSON for common token patterns before sharing
- **Phase: CI/CD** - Pre-commit hook to detect credentials in workflow JSON

**Actionable Detection:**
```bash
# Pre-commit hook
if grep -E '(sk-[a-zA-Z0-9]{32,}|ghp_[a-zA-Z0-9]{36}|Bearer [a-zA-Z0-9_-]{20,})' *.json; then
  echo "ERROR: Potential credential detected in workflow export!"
  exit 1
fi
```

**Sanitization Checklist:**
- [ ] All API keys use n8n Credential nodes
- [ ] HTTP Request headers use `{{$credentials.token}}` references
- [ ] Database connection strings in environment variables, not workflows
- [ ] Test data doesn't include real email addresses/phone numbers

**References:**
- [Does Workflow Export Include Credentials or Sensitive Data?](https://community.n8n.io/t/does-workflow-export-include-credentials-or-sensitive-data/182892)
- [How to Secure n8n Workflows: Step-by-Step Process](https://www.reco.ai/hub/secure-n8n-workflows)

---

### Problem: Credential Names Reveal System Architecture
**Symptom:** Exported workflow shows credential names like "Production_AWS_Admin" or "Anthropic_API_Personal"

**Root Cause:**
- Credential names chosen for developer convenience, not security
- Even without secrets, names expose integration points and privilege levels

**Impact:**
- Social engineering attack surface (attacker knows you use AWS + Anthropic)
- Workflow structure reveals business logic to competitors
- Compliance risk (reveals data flows to auditors unexpectedly)

**Prevention:**
- **Phase: Setup** - Use generic credential names ("cloud_provider_1", "ai_service_2")
- **Phase: Sharing** - Find/replace credential names in exports before sharing
- **Phase: Documentation** - Keep mapping of generic names → real services in separate secure doc

**Actionable Naming:**
```
BAD:  "anthropic_claude_production_tier4"
GOOD: "llm_provider_primary"

BAD:  "postgres_financial_data_rds"
GOOD: "database_main"
```

**References:**
- [n8n Security Best Practices](https://www.soraia.io/blog/n8n-security-best-practices-protect-your-data-and-workflows)

---

## 6. Context Window Management

### Problem: Conversation Memory Grows Unbounded Until Crash
**Symptom:** Bot works fine initially, then starts timing out after ~20 messages in a conversation

**Root Cause:**
- Buffer Window Memory or Postgres Chat Memory stores all messages
- Each request includes entire history in context window
- Eventually exceeds model's context limit (8k, 32k, etc.)

**Impact:**
- Long conversations fail mid-thread (bad UX)
- No graceful degradation - just timeout errors
- Memory costs for Gemini API scale with context size (even on free tier)

**Prevention:**
- **Phase: Design** - Use ConversationSummaryMemory to compress old messages
- **Phase: Configuration** - Set Context Window Length limit in n8n memory nodes
- **Phase: Monitoring** - Track token usage per request, alert when >75% of limit

**Actionable Configuration:**
```javascript
// n8n Simple Memory node settings
Context Window Length: 10  // Keep last 10 interactions only

// OR use hybrid approach in Code node
if (conversationTurns > 15) {
  // Summarize turns 1-10
  const summary = await llm.summarize(oldMessages);
  memory = [summary, ...recentMessages.slice(-5)];
}
```

**References:**
- [Context Window Management Strategies](https://apxml.com/courses/langchain-production-llm/chapter-3-advanced-memory-management/context-window-management)
- [Simple Memory node documentation](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.memorybufferwindow/)

---

### Problem: PostgreSQL Chat Memory Connection Pool Exhaustion
**Symptom:** First few messages work, then "cannot use a pool after calling end on the pool" error

**Root Cause:**
- n8n's Postgres Chat Memory node doesn't properly manage connection lifecycle
- Each message opens new connection without closing previous one
- Database reaches max_connections limit (default: 100)

**Impact:**
- Multi-user bot fails after ~50-100 total messages across all users
- Requires database restart to recover
- Connection leak continues on restart

**Prevention:**
- **Phase: Infrastructure** - Increase PostgreSQL `max_connections` (200+)
- **Phase: Workaround** - Use Redis Chat Memory instead (no connection pooling issues)
- **Phase: Monitoring** - Track open Postgres connections, alert at 80% threshold

**Actionable Monitoring:**
```sql
-- Run periodically
SELECT count(*) as open_connections, max_connections
FROM pg_stat_activity, pg_settings
WHERE name = 'max_connections';

-- Alert if open_connections > max_connections * 0.8
```

**References:**
- [PostgreSQL Connection Pool Not Closing Properly](https://github.com/n8n-io/n8n/issues/12653)
- [Problems with Postgres Memory Node in n8n - cannot use pool](https://community.n8n.io/t/problems-with-postgres-memory-node-in-n8n-cannot-use-pool/70540)

---

## 7. Rate Limit Handling

### Problem: Telegram 429 Errors During Bulk Notifications
**Symptom:** Bot successfully sends first 30 messages, then all subsequent messages fail with "Too Many Requests"

**Root Cause:**
- Telegram limits: 1 msg/sec per chat, 20 msg/min in groups, 30 msg/sec globally
- n8n processes items in parallel by default
- No built-in rate limiting in Telegram node

**Impact:**
- Birthday reminders send only to first 30 people
- Mass notifications fail silently for majority of users
- Telegram may temporarily ban bot for repeated violations

**Prevention:**
- **Phase: Design** - Use Loop Over Items + Wait node (1000ms delay)
- **Phase: Implementation** - Enable "Batching" in HTTP Request node (1 request/sec)
- **Phase: Error Handling** - Implement exponential backoff with jitter on 429 errors

**Actionable Configuration:**
```javascript
// n8n Loop Over Items node
Items: $('Get All Users').item

// Wait node after each iteration
Amount: 1000  // 1 second
Unit: Milliseconds

// OR use HTTP Request node batching
Batch Interval (ms): 1000
Batch Size: 1
```

**References:**
- [Handling API rate limits](https://docs.n8n.io/integrations/builtin/rate-limits/)
- [Telegram limit](https://community.n8n.io/t/telegram-limit/10010)
- [Bots FAQ](https://core.telegram.org/bots/faq)

---

### Problem: Gemini API Free Tier Daily Quota Exhaustion
**Symptom:** Bot works fine for first 100 requests, then all LLM calls fail with 429 "Resource exhausted"

**Root Cause:**
- Gemini 2.5 Pro free tier: only **100 requests per day** (reset at midnight Pacific)
- No warning as quota approaches
- No fallback to cheaper model

**Impact:**
- Bot becomes text-only after quota exhaustion (can't do intelligent routing)
- Unpredictable failure time (depends on daily usage pattern)
- Users blame bot, not understanding it's a quota issue

**Prevention:**
- **Phase: Design** - Track Gemini API usage with counter (Redis/Postgres)
- **Phase: Design** - Fallback chain: Gemini 2.5 Pro → Flash → Flash-Lite → Ollama
- **Phase: Monitoring** - Alert at 80% of daily quota, disable non-critical features

**Actionable Quota Tracking:**
```javascript
// n8n Code node before Gemini call
const today = new Date().toISOString().split('T')[0];
const usageKey = `gemini_usage:${today}`;
const currentUsage = await redis.get(usageKey) || 0;

if (currentUsage >= 80) {  // 80% of 100 requests
  // Use Ollama fallback instead
  return { llmProvider: 'ollama', model: 'qwen3:8b' };
}

await redis.incr(usageKey);
await redis.expire(usageKey, 86400);  // Expire at end of day
```

**Gemini Free Tier Limits (2026):**
- Gemini 2.5 Pro: 5 RPM, 100 RPD
- Gemini 2.5 Flash: 10 RPM, 250 RPD
- Gemini 2.5 Flash-Lite: 15 RPM, 1000 RPD
- All share 250,000 TPM limit

**References:**
- [Gemini API Free Tier Rate Limits: Complete Guide for 2026](https://www.aifreeapi.com/en/posts/gemini-api-free-tier-rate-limits)
- [Rate limits | Gemini API](https://ai.google.dev/gemini-api/docs/rate-limits)

---

## 8. Error Cascades When One Service Fails

### Problem: Single Node Failure Breaks Entire Workflow
**Symptom:** Ollama is down → workflow crashes → no fallback → user gets silence

**Root Cause:**
- Default n8n behavior: stop execution on first error
- No error handling configured on critical nodes
- No fallback/retry logic

**Impact:**
- One service outage causes complete bot unavailability
- Users have no visibility into what's broken
- Manual intervention required to recover

**Prevention:**
- **Phase: Design** - Identify critical path vs. nice-to-have features
- **Phase: Implementation** - Enable "Continue On Fail" for non-critical nodes
- **Phase: Implementation** - Add Try/Catch pattern with error workflows

**Actionable Pattern:**
```
[Telegram Trigger]
→ [Try: Ollama LLM]
  → On Success: [Format Response]
  → On Error: [Fallback: Gemini API]
    → On Error: [Last Resort: Simple Keyword Matching]
      → On Error: [Send "System Temporarily Unavailable"]
```

**Configuration:**
- Critical nodes: Enable "Retry On Fail" (3 attempts, exponential backoff)
- Non-critical nodes: Enable "Continue On Fail"
- All workflows: Set Error Workflow to centralized error handler

**References:**
- [Advanced n8n Error Handling and Recovery Strategies](https://www.wednesday.is/writing-articles/advanced-n8n-error-handling-and-recovery-strategies)
- [Error handling | n8n Docs](https://docs.n8n.io/flow-logic/error-handling/)

---

### Problem: Silent Failures with No Logging
**Symptom:** User reports "bot didn't respond", but n8n shows execution as "success"

**Root Cause:**
- Workflow continues despite internal errors due to "Continue On Fail"
- Error context lost between nodes
- No centralized error logging

**Impact:**
- Impossible to debug user-reported issues
- No metrics on failure rates by error type
- Cannot prioritize fixes without visibility

**Prevention:**
- **Phase: Deployment** - Configure centralized error workflow (Slack/email alerts)
- **Phase: Monitoring** - Log all errors to external system (Sentry, Datadog, or Postgres)
- **Phase: Operations** - Daily review of error workflow executions

**Actionable Error Logging:**
```javascript
// n8n Error Workflow (triggered on any workflow failure)
const errorData = {
  workflow: $json.workflow.name,
  execution_id: $json.execution.id,
  error_node: $json.error.node.name,
  error_message: $json.error.message,
  input_data: $json.error.context,
  timestamp: new Date().toISOString(),
  user_id: $json.execution.data.telegram_user_id  // If available
};

// Log to Postgres
await postgres.insert('error_log', errorData);

// Alert on critical errors
if (errorData.error_node === 'Financial_Transaction') {
  await slack.send('#alerts-critical', JSON.stringify(errorData));
}
```

**References:**
- [Creating error workflows in n8n](https://blog.n8n.io/creating-error-workflows-in-n8n/)
- [n8n Workflow Debugging & Advanced Error Handling Guide](https://cyberincomeinnovators.com/mastering-n8n-workflow-debugging-from-common-errors-to-resilient-ai-automations)

---

### Problem: Execution Data Lost During Out-of-Memory Crashes
**Symptom:** Workflow execution shows "Can't show data - The execution was interrupted"

**Root Cause:**
- n8n runs out of memory during large data processing
- Execution state not saved before crash
- No recovery mechanism

**Impact:**
- Cannot debug failed executions (no input data to reproduce)
- Long-running workflows lose all progress
- User requests disappear without trace

**Prevention:**
- **Phase: Infrastructure** - Allocate sufficient memory (4GB+ for n8n)
- **Phase: Design** - Use "Execute Workflow" node to isolate memory-intensive tasks
- **Phase: Monitoring** - Track n8n container memory usage, alert at 80%

**Actionable Memory Management:**
```javascript
// n8n Code node - process large datasets in chunks
const CHUNK_SIZE = 100;
for (let i = 0; i < items.length; i += CHUNK_SIZE) {
  const chunk = items.slice(i, i + CHUNK_SIZE);
  await processChunk(chunk);
  // Memory released between chunks
}
```

**References:**
- [Workflow Data Loss Due to Error](https://community.n8n.io/t/workflow-data-loss-due-to-error/122181)
- [Memory-related errors | n8n Docs](https://docs.n8n.io/hosting/scaling/memory-errors/)

---

## Priority Matrix for ADHD User

### Critical (Fix First - High Activation Energy Impact)
1. **Ollama model unloading** → 30s delays break "flow state"
2. **Silent webhook failures** → "Is it broken?" analysis paralysis
3. **Voice transcription failures** → Forces typing (high friction)

### High (Fix During Initial Deployment)
4. **Gemini quota exhaustion** → Unpredictable failures erode trust
5. **Credential exposure** → Security professional reputation risk
6. **Error cascade without fallback** → Complete system unavailability

### Medium (Fix Before Multi-User)
7. **Context window unbounded growth** → Works initially, fails later (confusing)
8. **PostgreSQL connection pool exhaustion** → Scales poorly
9. **LLM routing hallucinations** → Breaks trust in automation

### Low (Optimize Post-Launch)
10. **Telegram rate limits during bulk sends** → Workaround: send fewer notifications
11. **Ollama timeout on long tasks** → Rare edge case for 8B models

---

## Quick Reference: Prevention Phase Mapping

| Pitfall | Design | Implement | Deploy | Monitor | Ops |
|---------|--------|-----------|--------|---------|-----|
| Ollama timeout | Chunk tasks | HTTP not HTTPS | - | Load test | - |
| Ollama unloading | - | - | KEEP_ALIVE=-1 | Cold-start metrics | - |
| Webhook silence | Separate dev/prod bots | WEBHOOK_URL env | Validate webhook | Health checks | Daily restart |
| Voice transcription | Plan for ffmpeg | Add conversion node | Test with real Telegram | - | - |
| LLM routing hallucination | State machine pattern | Validation nodes | Eval dataset | Route accuracy | - |
| Credential exposure | Use Credentials, not headers | - | Pre-commit hook | - | - |
| Context window growth | Summarization strategy | Set window limit | - | Token tracking | - |
| Gemini quota | Fallback chain | Usage counter | - | 80% alert | Disable non-critical |
| Error cascade | Identify critical path | Try/Catch + fallbacks | Error workflow | Centralized logging | Daily error review |

---

## Sources

**Ollama & n8n Integration:**
- [Ollama chat Node has limited the 5 mins timeout](https://community.n8n.io/t/ollama-chat-node-has-limited-the-5-mins-timeout/43621)
- [Ollama taking so long to respond](https://community.n8n.io/t/ollama-taking-so-long-to-respond/216166)
- [Ollama Model node common issues](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.lmollama/common-issues/)
- [FAQ - Ollama](https://docs.ollama.com/faq)
- [Preventing Model Swapping In Ollama](https://blog.gopenai.com/preventing-model-swapping-in-ollama-a-guide-to-persistent-loading-f81f1dfb858d)

**Telegram Webhooks:**
- [Telegram Trigger webhook stops receiving messages](https://community.n8n.io/t/telegram-trigger-webhook-stops-receiving-messages/239239)
- [Telegram Trigger node common issues](https://docs.n8n.io/integrations/builtin/trigger-nodes/n8n-nodes-base.telegramtrigger/common-issues/)
- [Cloudflare Tunnel - Telegram Webhook not responding](https://community.n8n.io/t/cloudflare-tunnel-telegram-webhook-not-responding/61892)
- [Fixing n8n Webhook Problems](https://www.tva.sg/fixing-n8n-webhook-problems-the-complete-troubleshooting-guide-for-self-hosted-instances/)

**Voice Transcription:**
- [Voice messages transcribe fine — but uploaded audio files don't](https://community.n8n.io/t/voice-messages-transcribe-fine-but-uploaded-audio-files-don-t-even-with-corrected-mime/134761)
- [AI Agent node throws "No prompt specified" error](https://community.n8n.io/t/im-building-a-telegram-chatbot-in-n8n-that-uses-openai-to-process-both-text-and-voice-messages-text-messages-work-fine-but-for-voice-messages-the-ai-agent-node-throws-a-no-prompt-specified-error-even-though-the-transcription-exists/104129)

**LLM Hallucinations:**
- [Iterations, hallucinations, and lessons learned](https://blog.n8n.io/iterations-hallucinations-and-lessons-learned-rebuilding-our-ai-assistant-on-n8n/)
- [How to stop your AI agents from hallucinating: A guide to n8n's Eval Node](https://blog.logrocket.com/stop-your-ai-agents-from-hallucinating-n8n/)
- [How to build deterministic agentic AI with state machines in n8n](https://blog.logrocket.com/deterministic-agentic-ai-with-state-machines/)

**Security & Credentials:**
- [Does Workflow Export Include Credentials or Sensitive Data?](https://community.n8n.io/t/does-workflow-export-include-credentials-or-sensitive-data/182892)
- [How to Secure n8n Workflows: Step-by-Step Process](https://www.reco.ai/hub/secure-n8n-workflows)
- [n8n Security Best Practices](https://www.soraia.io/blog/n8n-security-best-practices-protect-your-data-and-workflows)

**Context Window Management:**
- [Context Window Management Strategies](https://apxml.com/courses/langchain-production-llm/chapter-3-advanced-memory-management/context-window-management)
- [Simple Memory node documentation](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.memorybufferwindow/)
- [PostgreSQL Connection Pool Not Closing Properly](https://github.com/n8n-io/n8n/issues/12653)
- [Problems with Postgres Memory Node in n8n - cannot use pool](https://community.n8n.io/t/problems-with-postgres-memory-node-in-n8n-cannot-use-pool/70540)

**Rate Limiting:**
- [Handling API rate limits](https://docs.n8n.io/integrations/builtin/rate-limits/)
- [Telegram limit](https://community.n8n.io/t/telegram-limit/10010)
- [Bots FAQ](https://core.telegram.org/bots/faq)
- [Gemini API Free Tier Rate Limits: Complete Guide for 2026](https://www.aifreeapi.com/en/posts/gemini-api-free-tier-rate-limits)
- [Rate limits | Gemini API](https://ai.google.dev/gemini-api/docs/rate-limits)

**Error Handling:**
- [Error handling | n8n Docs](https://docs.n8n.io/flow-logic/error-handling/)
- [Advanced n8n Error Handling and Recovery Strategies](https://www.wednesday.is/writing-articles/advanced-n8n-error-handling-and-recovery-strategies)
- [Creating error workflows in n8n](https://blog.n8n.io/creating-error-workflows-in-n8n/)
- [n8n Workflow Debugging & Advanced Error Handling Guide](https://cyberincomeinnovators.com/mastering-n8n-workflow-debugging-from-common-errors-to-resilient-ai-automations)
- [Workflow Data Loss Due to Error](https://community.n8n.io/t/workflow-data-loss-due-to-error/122181)
- [Memory-related errors | n8n Docs](https://docs.n8n.io/hosting/scaling/memory-errors/)
