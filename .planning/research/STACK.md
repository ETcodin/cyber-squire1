# Telegram-First AI Command Router Stack (2025)

> **Target:** EC2 t3.xlarge | n8n + PostgreSQL + Ollama (qwen2.5:7b)
> **Constraint:** FREE inference only (Ollama local, Gemini free tier, manual Claude escalation)
> **Output Style:** ADHD-optimized (bold key points, 3 bullets max, single next-step)

---

## 1. Telegram Integration: Webhook vs Polling

### Recommendation: **Webhook** (with polling fallback for dev/IPv6 edge cases)

| Factor | Webhook | Long Polling |
|--------|---------|--------------|
| **Latency** | Instant push | 60s max wait |
| **Reliability** | Requires HTTPS + public IP | Works behind NAT/IPv6 |
| **n8n Support** | Native Telegram Trigger node | Community node or HTTP Request |
| **Production** | Recommended | Testing only |

**Key Decision Points:**
- **Use Webhook** if your n8n instance has a public HTTPS endpoint (Cloudflare Tunnel handles this)
- **Use Polling** only if you lack IPv4/HTTPS access or during local development
- Community polling node: [`n8n-nodes-telegram-polling`](https://github.com/bergi9/n8n-nodes-telegram-polling)

**Setup Steps:**
1. Create bot via [@BotFather](https://t.me/BotFather) with `/newbot`
2. Store token in n8n credentials (never hardcode)
3. Use Telegram Trigger node (auto-registers webhook with Telegram API)
4. Ensure n8n is HTTPS-accessible (required by Telegram)

**Known Issue:** Telegram Trigger webhooks can stop receiving messages after extended uptime. Mitigation: scheduled workflow to re-register webhook daily.

---

## 2. Voice Transcription: Free Whisper Alternatives

### Recommendation: **faster-whisper** via LinuxServer.io Docker image

**Why faster-whisper:**
- 4x faster than OpenAI Whisper with same accuracy
- CTranslate2 backend optimized for CPU (your t3.xlarge has no GPU)
- int8 quantization: 2-3x speed boost, minimal quality loss
- VAD (Voice Activity Detection): 20-40% faster by skipping silence

**Docker Compose Addition:**
```yaml
services:
  faster-whisper:
    image: lscr.io/linuxserver/faster-whisper:latest
    container_name: faster-whisper
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - WHISPER_MODEL=base  # Options: tiny, base, small, medium, large-v3
      - WHISPER_BEAM=1
      - WHISPER_LANG=en
    volumes:
      - ./whisper-data:/config
    ports:
      - "10300:10300"
    restart: unless-stopped
```

**Model Size vs Speed (CPU, int8):**
| Model | VRAM/RAM | Speed | Use Case |
|-------|----------|-------|----------|
| tiny | ~1GB | Fastest | Quick commands |
| base | ~1GB | Fast | **Recommended for t3.xlarge** |
| small | ~2GB | Medium | Better accuracy |
| medium | ~5GB | Slow | High accuracy |

**Telegram Voice Message Handling:**
- Telegram sends `.oga` files (Opus in Ogg container)
- Must convert to `.mp3` or `.ogg` before transcription
- n8n workflow: Use Code node to rename/convert binary MIME type:
```javascript
// In n8n Code node after Telegram Trigger
const items = $input.all();
for (const item of items) {
  if (item.binary?.data) {
    item.binary.data.fileName = 'audio.ogg';
    item.binary.data.mimeType = 'audio/ogg';
  }
}
return items;
```

**Alternative Options:**
| Tool | Pros | Cons |
|------|------|------|
| [Vosk](https://alphacephei.com/vosk/) | Lightweight, offline, low RAM | Lower accuracy than Whisper |
| [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) | C++ port, very fast | Requires compilation |
| [Moonshine](https://github.com/usefulsensors/moonshine) | Optimized for edge devices | Newer, less tested |

---

## 3. Ollama Integration in n8n

### Recommendation: **Native Ollama Chat Model node** (not HTTP Request)

**Why Native Node:**
- Built-in credential management
- Automatic token counting
- Works with AI Agent node for tool calling
- Simpler error handling

**Docker Networking (Critical):**
```yaml
# docker-compose.yml
services:
  n8n:
    # ... your n8n config
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Required for Linux

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    environment:
      - OLLAMA_KEEP_ALIVE=24h  # Prevents cold starts
      - OLLAMA_HOST=0.0.0.0    # Accept external connections
    volumes:
      - ./ollama-data:/root/.ollama
    ports:
      - "11434:11434"
```

**n8n Credential Setup:**
- Base URL: `http://ollama:11434` (same Docker network) or `http://host.docker.internal:11434`
- If connection fails, try `127.0.0.1` instead of `localhost`

**Node Selection Guide:**
| Node | Use Case | Limitation |
|------|----------|------------|
| **Ollama Chat Model** | Conversations, AI Agent | Recommended |
| Ollama Model | Text completion tasks | No tool support |
| HTTP Request | Custom API calls | Manual error handling |

**qwen2.5:7b Performance:**
- **RAM:** ~7.5GB for 7B model
- **Context:** 128K tokens supported
- **Tool Calling:** Native support via Ollama
- **System Prompt:** Highly resilient to diverse prompts (good for command routing)

**System Prompt for Command Routing:**
```
You are a command router. Analyze user messages and output ONLY a JSON object.

Categories:
- "task": Task/todo management
- "calendar": Scheduling/events
- "finance": Money/expenses
- "search": Information lookup
- "general": Conversation

Output format: {"intent": "category", "confidence": 0.0-1.0, "entities": {}}
```

---

## 4. Gemini Free Tier Integration (Fallback)

### Recommendation: **Gemini 2.5 Flash-Lite** as fallback (highest free quota)

**Free Tier Limits (as of Jan 2025 - subject to change):**
| Model | RPM | RPD | Best For |
|-------|-----|-----|----------|
| Gemini 2.5 Pro | 5 | 100 | Complex reasoning |
| Gemini 2.5 Flash | 10 | 250 | General use |
| **Gemini 2.5 Flash-Lite** | 15 | **1,000** | High volume |

**Warning:** Google reduced free tier limits by ~92% in Dec 2025. Treat free tier as promotional, not reliable baseline.

**n8n Integration:**
1. Get API key from [Google AI Studio](https://aistudio.google.com/)
2. Use **HTTP Request node** (more control) or **Google Gemini Chat Model node**
3. Set up as fallback in AI Agent node settings

**Fallback Architecture:**
```
User Message
    |
    v
[Ollama qwen2.5:7b] --error--> [Gemini Flash-Lite] --error--> [Manual Queue]
    |                              |
    v                              v
  Response                      Response
```

**Fallback Implementation in n8n:**
- AI Agent node has built-in "Fallback Model" option
- Enable it and configure secondary LLM credentials
- Automatically switches on primary model failure

**Rate Limit Handling:**
```javascript
// In Code node after Gemini call
if ($json.error?.status === 429) {
  // Queue for manual review or delay retry
  return { escalate: true, reason: 'rate_limit' };
}
```

---

## 5. Session/Memory Handling (PostgreSQL)

### Recommendation: **Postgres Chat Memory node** with per-user session IDs

**Why PostgreSQL:**
- Already in your stack (no new dependencies)
- Survives restarts/deployments
- SQL queryable for analytics
- Free (self-hosted)

**n8n Setup:**
1. Add **Postgres Chat Memory** sub-node to AI Agent
2. Configure PostgreSQL credentials
3. Set **Context Window Length**: 10-15 messages (balance between context and tokens)
4. **Critical:** Use dynamic session ID (not hardcoded)

**Session ID Strategy:**
```javascript
// In Code node before AI Agent
const telegramUserId = $json.message.from.id;
const chatId = $json.message.chat.id;
const sessionId = `tg_${chatId}_${telegramUserId}`;

return { sessionId };
```

**Schema (auto-created by n8n):**
```sql
CREATE TABLE n8n_chat_histories (
  id SERIAL PRIMARY KEY,
  session_id VARCHAR(255) NOT NULL,
  message JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_session_id ON n8n_chat_histories(session_id);
```

**Context Window Best Practices:**
- **10-20 messages** is optimal (not entire history)
- Larger windows = more tokens = slower + costlier
- Implement periodic summarization for long conversations

**Known Bug (2025):** AI Agent doesn't store Tool call messages in memory, causing confusion. Workaround: manually log tool usage in a separate table.

---

## Complete Architecture Diagram

```
                    Telegram Cloud
                         |
                         | Webhook (HTTPS)
                         v
+----------------------------------------------------------+
|                    EC2 t3.xlarge                          |
|                                                           |
|  +-------------+      +---------------------------+       |
|  | Cloudflare  |----->|         n8n               |       |
|  | Tunnel      |      |  +---------------------+  |       |
|  +-------------+      |  | Telegram Trigger    |  |       |
|                       |  +----------+----------+  |       |
|                       |             |             |       |
|                       |             v             |       |
|                       |  +---------------------+  |       |
|                       |  | Code: OGA->OGG      |  |       |
|                       |  +----------+----------+  |       |
|                       |             |             |       |
|                       |             v             |       |
|  +---------------+    |  +---------------------+  |       |
|  | faster-whisper|<---|  | HTTP: Transcribe    |  |       |
|  | :10300        |    |  +----------+----------+  |       |
|  +---------------+    |             |             |       |
|                       |             v             |       |
|  +---------------+    |  +---------------------+  |       |
|  | Ollama        |<---|  | AI Agent            |  |       |
|  | qwen2.5:7b    |    |  | + Postgres Memory   |  |       |
|  | :11434        |    |  | + Gemini Fallback   |  |       |
|  +---------------+    |  +----------+----------+  |       |
|                       |             |             |       |
|  +---------------+    |             v             |       |
|  | PostgreSQL    |<---|  +---------------------+  |       |
|  | :5432         |    |  | Telegram: Reply     |  |       |
|  | - Chat Memory |    |  +---------------------+  |       |
|  | - Workflow DB |    +---------------------------+       |
|  +---------------+                                        |
+----------------------------------------------------------+
```

---

## Resource Allocation (t3.xlarge: 16GB RAM)

| Service | RAM Allocation | Notes |
|---------|---------------|-------|
| PostgreSQL | 4GB | Shared buffers + connections |
| n8n | 2GB | Workflow execution |
| Ollama (qwen2.5:7b) | 7.5GB | Model loaded in memory |
| faster-whisper (base) | 1GB | Per-request, releases after |
| OS + Buffer | 1.5GB | System overhead |

**Total:** ~16GB (fully utilized)

---

## Version Matrix

| Component | Version | Source |
|-----------|---------|--------|
| n8n | 1.72.x+ | Required for Fallback LLM feature |
| Ollama | 0.5.x+ | Tool calling support |
| qwen2.5 | 7b-instruct | `ollama pull qwen2.5:7b-instruct` |
| faster-whisper | latest | LinuxServer.io image |
| PostgreSQL | 16.x | Current stable |
| Docker Compose | v2.x | Modern syntax |

---

## Quick Start Checklist

- [ ] Create Telegram bot via @BotFather, save token
- [ ] Add faster-whisper container to docker-compose
- [ ] Configure Ollama networking (`host.docker.internal` or shared network)
- [ ] Pull qwen2.5:7b-instruct model
- [ ] Set up n8n credentials: Telegram, Ollama, PostgreSQL, Google AI Studio
- [ ] Create workflow: Telegram Trigger -> Audio Processing -> AI Agent -> Reply
- [ ] Configure Postgres Chat Memory with dynamic session ID
- [ ] Enable Gemini fallback in AI Agent node
- [ ] Test with text message, then voice message
- [ ] Set up error workflow for monitoring

---

## References

### Telegram & n8n
- [n8n Telegram Integration](https://n8n.io/integrations/telegram/)
- [Telegram Credentials Setup](https://docs.n8n.io/integrations/builtin/credentials/telegram/)
- [Webhook vs Polling - grammY](https://grammy.dev/guide/deployment-types)
- [n8n Telegram Polling Node](https://github.com/bergi9/n8n-nodes-telegram-polling)

### Voice Transcription
- [Top Open Source STT Models 2025](https://modal.com/blog/open-source-stt)
- [LinuxServer faster-whisper](https://docs.linuxserver.io/images/docker-faster-whisper/)
- [faster-whisper-api](https://github.com/imWildCat/faster-whisper-api)
- [Whisper ASR Webservice](https://hub.docker.com/r/onerahmet/openai-whisper-asr-webservice)

### Ollama & n8n
- [Ollama n8n Integration](https://docs.ollama.com/integrations/n8n)
- [n8n Ollama Model Node](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.lmollama/)
- [Ollama Common Issues](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.lmollama/common-issues/)
- [Self-hosted AI with n8n + Ollama](https://ngrok.com/blog/self-hosted-local-ai-workflows-with-docker-n8n-ollama-and-ngrok-2025)

### Gemini
- [Gemini Free Tier Limits 2025](https://www.aifreeapi.com/en/posts/gemini-api-free-tier-limit)
- [n8n Google Gemini Integration](https://n8n.io/integrations/google-gemini-chat-model/)

### Memory & Sessions
- [Postgres Chat Memory Node](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.memorypostgreschat/)
- [n8n AI Agent Memory Guide](https://towardsai.net/p/machine-learning/n8n-ai-agent-node-memory-complete-setup-guide-for-2026)

### Error Handling
- [n8n Error Handling Docs](https://docs.n8n.io/flow-logic/error-handling/)
- [AI Agent Deployment Best Practices](https://blog.n8n.io/best-practices-for-deploying-ai-agents-in-production/)
- [Auto-retry Workflow Template](https://n8n.io/workflows/3144-auto-retry-engine-error-recovery-workflow/)

---

*Last Updated: 2026-02-04*
