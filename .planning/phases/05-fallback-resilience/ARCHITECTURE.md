# Phase 5: Fallback & Resilience Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      TELEGRAM USER INTERFACE                     │
│                    (Emmanuel's Telegram Chat)                    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     n8n WORKFLOW ENGINE                          │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  INGESTION LAYER                                           │ │
│  │  [Telegram Trigger] → [Deduplication] → [Parse Input]     │ │
│  └──────────────────────┬─────────────────────────────────────┘ │
│                         │                                         │
│                         ▼                                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  PRIMARY AI PATH (Ollama)                                  │ │
│  │                                                             │ │
│  │  [Ollama Wrapper] ──────┐                                  │ │
│  │         │                │                                  │ │
│  │         ▼                │                                  │ │
│  │  ┌──────────────────┐   │  Metadata:                       │ │
│  │  │ Supervisor Agent │   │  - startTime                     │ │
│  │  │   (LangChain)    │   │  - provider: 'ollama'            │ │
│  │  │                  │   │  - attemptNumber: 1              │ │
│  │  │  Tools:          │   │                                  │ │
│  │  │  • ADHD Cmdr     │   │                                  │ │
│  │  │  • Finance Mgr   │   │                                  │ │
│  │  │  • System Status │   │                                  │ │
│  │  └──────────────────┘   │                                  │ │
│  │         │                │                                  │ │
│  │         ▼                │                                  │ │
│  │  ┌──────────────────┐   │                                  │ │
│  │  │ Ollama Qwen 2.5  │   │                                  │ │
│  │  │ localhost:11434  │◄──┘                                  │ │
│  │  │ qwen2.5:7b       │                                      │ │
│  │  └──────────────────┘                                      │ │
│  │         │                                                   │ │
│  │         ▼                                                   │ │
│  │  [Check Agent Success] ─── Success? ──────────────┐        │ │
│  │         │                                          │        │ │
│  │         │ Failure (output null/undefined/empty)   │        │ │
│  │         ▼                                          │        │ │
│  └────────────────────────────────────────────────────┼────────┘ │
│                                                        │          │
│                                                        │          │
│  ┌────────────────────────────────────────────────────┼────────┐ │
│  │  FALLBACK AI PATH (Gemini)                         │        │ │
│  │                                                     │        │ │
│  │  [Prepare Gemini Fallback] ◄────────────────────────┘        │ │
│  │         │                                                    │ │
│  │         │ Build prompt with:                                │ │
│  │         │ • System identity (CYBER-SQUIRE)                  │ │
│  │         │ • Recent chat history (from memory)               │ │
│  │         │ • User message                                    │ │
│  │         │                                                    │ │
│  │         ▼                                                    │ │
│  │  ┌─────────────────────────────────────┐                    │ │
│  │  │   Call Gemini API (HTTP Request)    │                    │ │
│  │  │                                      │                    │ │
│  │  │   POST https://generativelanguage   │                    │ │
│  │  │     .googleapis.com/v1beta/models/  │                    │ │
│  │  │     gemini-2.5-flash-lite:generate  │                    │ │
│  │  │                                      │                    │ │
│  │  │   Header: Content-Type: JSON        │                    │ │
│  │  │   Query: ?key=$GEMINI_API_KEY       │                    │ │
│  │  │   Timeout: 15s                      │                    │ │
│  │  └─────────────────────────────────────┘                    │ │
│  │         │                        │                          │ │
│  │         │                        │ Error (quota/timeout)    │ │
│  │         │                        ▼                          │ │
│  │         │              ┌───────────────────────┐            │ │
│  │         │              │ Handle Gemini Failure │            │ │
│  │         │              │                       │            │ │
│  │         │              │ Returns:              │            │ │
│  │         │              │ "⚠️ AI systems       │            │ │
│  │         │              │  experiencing issues" │            │ │
│  │         │              └───────────────────────┘            │ │
│  │         │                        │                          │ │
│  │         ▼                        │                          │ │
│  │  [Parse Gemini Response]        │                          │ │
│  │         │                        │                          │ │
│  │         │ Add metadata:          │                          │ │
│  │         │ • provider: 'gemini'   │                          │ │
│  │         │ • fallback: true       │                          │ │
│  │         │ • latencyMs            │                          │ │
│  │         │                        │                          │ │
│  │         │ Append footer:         │                          │ │
│  │         │ "_via Gemini fallback_"│                          │ │
│  │         │                        │                          │ │
│  │         ▼                        │                          │ │
│  │  [Log Fallback Event]           │                          │ │
│  │         │                        │                          │ │
│  │         │ Console: AI_FALLBACK   │                          │ │
│  │         │ Database: ai_failures  │                          │ │
│  │         │                        │                          │ │
│  │         ▼                        │                          │ │
│  │  [Check Escalation Needed]      │                          │ │
│  │         │                        │                          │ │
│  │         │ Query: failures in     │                          │ │
│  │         │ last 10 minutes >= 3?  │                          │ │
│  │         │                        │                          │ │
│  │         │ No: Continue           │                          │ │
│  │         │ Yes: Add escalation    │                          │ │
│  │         │      header to response│                          │ │
│  │         │                        │                          │ │
│  │         └────────┬───────────────┘                          │ │
│  │                  │                                           │ │
│  └──────────────────┼───────────────────────────────────────────┘ │
│                     │                                             │
│                     ▼                                             │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  UNIFIED OUTPUT PATH                                       │ │
│  │                                                             │ │
│  │  [Merge Paths] ← (Ollama success OR Gemini fallback)      │ │
│  │         │                                                   │ │
│  │         ▼                                                   │ │
│  │  [Log Routing Decision] ← Confidence scoring              │ │
│  │         │                                                   │ │
│  │         ▼                                                   │ │
│  │  [Format Output] ← Telegram 4096 char limit               │ │
│  │         │                                                   │ │
│  │         ▼                                                   │ │
│  │  [Log Outgoing Response] ← Latency tracking               │ │
│  │         │                                                   │ │
│  │         ▼                                                   │ │
│  │  [Send Response] ← Telegram sendMessage                   │ │
│  │         │                                                   │ │
│  │         ▼                                                   │ │
│  │  [Mark Complete] ← Update message status in DB            │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     POSTGRESQL DATABASE                          │
│                                                                   │
│  Tables:                                                          │
│  • telegram_message_log ← Deduplication                          │
│  • chat_memory          ← Conversation history                   │
│  • ai_failures          ← Fallback event log (NEW)               │
│                                                                   │
│  Views:                                                           │
│  • v_daily_fallback_metrics    ← Fallback rate                  │
│  • v_hourly_failure_rate       ← Failure trends                 │
│  • v_escalation_status         ← Active escalations             │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

### Successful Ollama Request
```
User: "What should I work on?"
    │
    ▼
[Telegram] → [Dedup] → [Parse] → [Ollama Wrapper]
                                        │
                                        ▼
                              [Supervisor Agent + Ollama]
                                        │
                                        ▼
                              [ADHD Commander Tool Call]
                                        │
                                        ▼
                              Response: "Focus on Phase 5..."
                                        │
                                        ▼
                              [Check Success] ✅ output exists
                                        │
                                        ▼
                              [Merge Paths] → [Format] → [Send]
                                        │
                                        ▼
                              User receives: "Focus on Phase 5..."
```

### Ollama Failure → Gemini Fallback
```
User: "Check system health"
    │
    ▼
[Telegram] → [Dedup] → [Parse] → [Ollama Wrapper]
                                        │
                                        ▼
                              [Supervisor Agent + Ollama]
                                        │
                                        ✗ (Ollama timeout/down)
                                        │
                                        ▼
                              [Check Success] ❌ output null
                                        │
                                        ▼
                              [Prepare Gemini Fallback]
                                        │
                              Prompt: "You are CYBER-SQUIRE...
                                       User: Check system health"
                                        │
                                        ▼
                              [Call Gemini API]
                              POST /generateContent
                                        │
                                        ▼
                              [Parse Gemini Response]
                              + "_via Gemini fallback_"
                                        │
                                        ▼
                              [Log Fallback Event]
                              → console.log('AI_FALLBACK')
                              → INSERT ai_failures
                                        │
                                        ▼
                              [Merge Paths] → [Format] → [Send]
                                        │
                                        ▼
                              User receives: "System status...
                                              _via Gemini fallback_"
```

### Dual Failure → Static Error
```
User: "Give me a task"
    │
    ▼
[Ollama] ✗ down
    │
    ▼
[Gemini API] ✗ quota exhausted (429)
    │
    ▼
[Handle Gemini Failure]
    │
    ▼
Response: "🔧 AI capacity temporarily limited.
           For urgent tasks, contact @ETcodin."
```

## Database Schema

### ai_failures Table
```sql
┌────────────────┬──────────────┬─────────────────────────────┐
│ Column         │ Type         │ Description                 │
├────────────────┼──────────────┼─────────────────────────────┤
│ id             │ SERIAL       │ Primary key                 │
│ chat_id        │ VARCHAR(50)  │ Telegram chat ID            │
│ message_id     │ BIGINT       │ Telegram message ID         │
│ failure_type   │ VARCHAR(20)  │ timeout/error/quota         │
│ provider       │ VARCHAR(20)  │ ollama/gemini/none          │
│ error_detail   │ TEXT         │ Error message               │
│ timestamp      │ TIMESTAMP    │ When failure occurred       │
│ resolved       │ BOOLEAN      │ Auto-resolved?              │
│ resolved_at    │ TIMESTAMP    │ When auto-resolved          │
└────────────────┴──────────────┴─────────────────────────────┘

Indexes:
• idx_ai_failures_chat_time (chat_id, timestamp DESC)
• idx_ai_failures_unresolved (resolved) WHERE resolved=FALSE
• idx_ai_failures_provider (provider, timestamp DESC)

Trigger: auto_resolve_old_failures (after INSERT)
  → Sets resolved=TRUE for entries >1 hour old
```

## Network Flow

```
┌──────────────┐
│   User       │
│ (Telegram)   │
└──────┬───────┘
       │ HTTPS
       ▼
┌──────────────────────────────────────────────────────────┐
│              EC2 Instance (t3.xlarge)                     │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Docker Container: n8n                             │  │
│  │  Port: 5678                                        │  │
│  │                                                     │  │
│  │  Workflow: workflow_supervisor_agent.json          │  │
│  └────────┬────────────────────────────────┬──────────┘  │
│           │                                 │             │
│           │ localhost:11434                 │ env var     │
│           ▼                                 ▼             │
│  ┌────────────────┐              ┌──────────────────┐    │
│  │ Docker:        │              │ Environment:     │    │
│  │ Ollama         │              │ GEMINI_API_KEY   │    │
│  │ qwen2.5:7b     │              └──────────────────┘    │
│  │ 7.5GB RAM      │                        │             │
│  └────────────────┘                        │             │
│           │                                 │             │
│           │ localhost:5432                  │ HTTPS       │
│           ▼                                 ▼             │
│  ┌────────────────┐         ┌──────────────────────────┐ │
│  │ Docker:        │         │   Google Cloud           │ │
│  │ PostgreSQL 16  │         │   Gemini API             │ │
│  │ 4GB RAM        │         │   generativelanguage     │ │
│  │                │         │   .googleapis.com        │ │
│  │ Databases:     │         │                          │ │
│  │ • n8n          │         │   Model:                 │ │
│  │   - ai_failures│         │   gemini-2.5-flash-lite  │ │
│  │   - chat_memory│         │                          │ │
│  │   - telegram_  │         │   Rate Limits:           │ │
│  │     message_log│         │   • 15 RPM               │ │
│  └────────────────┘         │   • 1000 RPD             │ │
│                             └──────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

## Latency Budget

```
Ollama Path (Success):
──────────────────────────────────────────────────────────
[Deduplication]                    100ms
[Parse Input]                       50ms
[Ollama Wrapper]                    10ms
[Supervisor Agent]               5,000ms  ← Primary latency
[Check Success]                     10ms
[Routing Decision Log]             200ms
[Format Output]                     20ms
[Send Response]                    300ms
──────────────────────────────────────────────────────────
Total:                          ~5,690ms

Gemini Fallback Path (Ollama Failed):
──────────────────────────────────────────────────────────
[Deduplication]                    100ms
[Parse Input]                       50ms
[Ollama Wrapper]                    10ms
[Supervisor Agent]              30,000ms  ← Timeout (failed)
[Check Success]                     10ms
[Prepare Gemini Fallback]          100ms
[Call Gemini API]               15,000ms  ← Gemini latency
[Parse Gemini Response]            100ms
[Log Fallback Event]               200ms  ← DB INSERT
[Check Escalation]                 150ms  ← DB SELECT
[Routing Decision Log]             200ms
[Format Output]                     20ms
[Send Response]                    300ms
──────────────────────────────────────────────────────────
Total:                         ~46,240ms (46 seconds)

User Experience: ~40s delay during fallback (acceptable
for high availability vs. complete failure)
```

## Failure Modes & Handling

### 1. Ollama Timeout
**Trigger:** Agent output null/undefined after execution
**Handling:** Automatic Gemini fallback
**User Impact:** +35s latency, "_via Gemini fallback_" footer
**Recovery:** Automatic on Ollama restart

### 2. Ollama Service Down
**Trigger:** Same as timeout
**Handling:** Same as timeout
**User Impact:** Same as timeout
**Recovery:** Manual (`docker start ollama`)

### 3. Gemini API Error (500/503)
**Trigger:** HTTP error response from Gemini
**Handling:** "Handle Gemini Failure" node
**User Impact:** Static error message
**Recovery:** Automatic (retry next request)

### 4. Gemini Quota Exhausted (429)
**Trigger:** HTTP 429 or "quota" in error message
**Handling:** Special quota message
**User Impact:** "AI capacity limited, retry in 1 hour"
**Recovery:** Wait for daily reset or upgrade tier

### 5. Dual Failure (Both AIs Down)
**Trigger:** Ollama timeout + Gemini error
**Handling:** Static fallback message
**User Impact:** Cannot process request
**Recovery:** Manual intervention required

### 6. Database Unavailable
**Trigger:** PostgreSQL connection failure
**Handling:** n8n workflow continues (logging fails silently)
**User Impact:** No chat memory, no failure logging
**Recovery:** Restart PostgreSQL, workflows auto-reconnect

## Resource Utilization

### Normal Operation (Ollama Only)
```
CPU:     10-15% (qwen2.5:7b inference)
Memory:  7.5GB (Ollama model) + 2GB (n8n) = 9.5GB / 16GB
Disk:    8GB (Ollama models)
Network: Minimal (Telegram API only)
```

### Fallback Operation (Gemini Active)
```
CPU:     5% (no local inference)
Memory:  2GB (n8n only, Ollama idle)
Disk:    No change
Network: +500KB per Gemini request (HTTP POST + response)
```

### Cost Analysis
```
Ollama:     $0/month (self-hosted)
Gemini:     $0/month (free tier, 1000 RPD)
PostgreSQL: $0/month (self-hosted)
n8n:        $0/month (self-hosted)
──────────────────────────────────────
Total:      $0/month

Projected Usage:
• ~50 messages/day
• Fallback rate <5%
• Gemini usage: ~2-3 requests/day
• Well within free tier limits
```

## Security Considerations

### API Key Storage
- `GEMINI_API_KEY` stored in `.env` (git-ignored)
- Passed via environment variable (not in code)
- No key logging (masked in console output)

### Data Privacy
**Ollama (Primary):**
- All data stays on EC2 instance
- No external API calls
- Full data sovereignty

**Gemini (Fallback):**
- User messages sent to Google API
- No conversation history shared (single-turn prompts)
- Google privacy policy applies
- Consider for non-sensitive deployments only

### Network Security
- Gemini API over HTTPS only
- No credential storage in workflow JSON
- PostgreSQL accessible only from localhost

## Monitoring Points

### Metrics to Track
1. **Fallback Rate:** `COUNT(*) WHERE provider='gemini' / total_messages`
2. **Ollama MTBF:** Mean time between Ollama failures
3. **Gemini Latency P95:** 95th percentile response time
4. **Quota Usage:** Daily Gemini API requests vs. 1000 limit
5. **Escalation Events:** Failures requiring manual intervention

### Alerting Thresholds
- **Warning:** Fallback rate >10% in 1 hour
- **Critical:** >3 escalations in 1 hour
- **Info:** Gemini quota >800 requests in 24h

### Log Queries
```sql
-- Fallback rate (last 24h)
SELECT
  COUNT(*) FILTER (WHERE provider = 'gemini') * 100.0 / COUNT(*) as fallback_pct
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '24 hours';

-- Escalation candidates
SELECT chat_id, COUNT(*) as failures
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '10 minutes'
  AND resolved = FALSE
GROUP BY chat_id
HAVING COUNT(*) >= 3;
```

---

**Architecture Version:** 4.0 (Phase 5)
**Last Updated:** 2026-02-04
**Status:** Production-Ready
