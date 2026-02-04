# Research Summary: Cyber-Squire Telegram Router

**Date:** 2026-02-04
**Scope:** n8n + Telegram + Ollama integration for ADHD-optimized command routing

---

## Key Findings

### Stack Decisions

| Component | Recommendation | Rationale |
|-----------|---------------|-----------|
| **Telegram** | Webhook (via Cloudflare Tunnel) | Instant push, already set up |
| **Voice Transcription** | faster-whisper (Docker) | Free, 4x faster than OpenAI, no GPU needed |
| **Primary LLM** | Ollama qwen2.5:7b | Local, free, 128K context, tool calling |
| **Fallback LLM** | Gemini 2.5 Flash-Lite | Free tier (15 RPM, 1000 RPD) |
| **Memory** | PostgreSQL Chat Memory | Already in stack, persistent |

### Architecture

**Recommended:** AI Supervisor with Modular Agents

```
Telegram → Supervisor Agent → [ADHD Commander | Finance | Security | Status]
                 ↓
         PostgreSQL (memory, logs)
                 ↓
              Ollama → Gemini fallback
```

**Critical Changes:**
1. Consolidate 30 workflow versions into 1 supervisor + 4 agent sub-workflows
2. Replace If-cascade routing with LangChain AI Agent
3. Move hardcoded credentials to n8n credential system

### Table Stakes Features

- `/start`, `/help`, `/status` commands
- Voice transcription pipeline
- Inline Yes/No confirmation buttons
- Markdown formatting with emoji indicators
- Error handling with graceful degradation

### ADHD-Optimized Differentiators

1. **TL;DR + expandable details** — Single-screen comprehension
2. **Progressive voice status** — "Transcribing... Processing... Done"
3. **Priority selector buttons** — [🔴 High] [🟡 Medium] [🟢 Low]
4. **Quiet hours** — No notifications 10pm-8am
5. **Voice confirmation echo** — "You said: [transcription]"

### Critical Pitfalls to Avoid

| Pitfall | Prevention | Phase |
|---------|------------|-------|
| Ollama 5-min timeout | Chunk large tasks | Design |
| Model unloading (30s cold start) | `OLLAMA_KEEP_ALIVE=24h` | Deploy |
| Hardcoded bot token | Move to credentials | Phase 1 |
| Webhook silent failures | Daily re-registration | Deploy |
| Gemini quota exhaustion | Track usage, implement fallback | Monitor |
| Voice .oga format rejection | Convert to .ogg in Code node | Implement |

### Resource Allocation (t3.xlarge 16GB)

| Service | Memory |
|---------|--------|
| PostgreSQL | 4GB |
| n8n | 2GB |
| Ollama qwen2.5:7b | 7.5GB |
| faster-whisper | 1GB |
| OS buffer | 1.5GB |

---

## Implementation Roadmap

### Phase 1: Foundation (Critical)
- Clean supervisor workflow with proper credentials
- Error handler with Telegram alerts
- faster-whisper Docker container

### Phase 2: Core Agents
- ADHD Commander (Notion integration)
- Finance Manager (transaction tracking)
- System Status (health checks)

### Phase 3: Extended Tools
- Security Scan (Nmap/Nuclei)
- Create Task (Notion API)
- GovCon Auditor (SAM.gov monitoring)

### Phase 4: Consolidation
- Archive 20+ obsolete workflow versions
- Document final architecture
- Implement quiet hours

### Phase 5: Optimization
- Analytics dashboard
- Performance tuning
- A/B testing routing prompts

---

## Security Reminders

**Rotate Immediately:**
- Telegram Bot Token (exposed in workflow_master_router_v5.json)

**Never Commit:**
- Workflow exports with hardcoded credentials
- `.env` files with real tokens

**Always Use:**
- n8n credential references (`{{ $credentials.telegram }}`)
- Environment variables for sensitive config

---

*See individual research files for detailed analysis:*
- `STACK.md` — Technology stack recommendations
- `FEATURES.md` — Feature prioritization matrix
- `ARCHITECTURE.md` — System design patterns
- `PITFALLS.md` — Common failure modes and prevention
