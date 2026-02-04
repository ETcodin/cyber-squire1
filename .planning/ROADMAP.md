# Roadmap: Cyber-Squire Telegram Router

**Created:** 2026-02-04
**Depth:** Comprehensive (8-12 phases, 5-10 plans each)
**Core Metric:** Message-to-workflow routing success rate

---

## Phase Overview

| Phase | Name | Requirements | Dependencies |
|-------|------|--------------|--------------|
| 1 | Infrastructure Foundation | INFRA-02, INFRA-03, INFRA-04, ROUTE-06 | None |
| 2 | Webhook & Message Intake | ROUTE-01, ROUTE-07 | Phase 1 |
| 3 | AI Routing Core | ROUTE-02, ROUTE-03 | Phase 2 |
| 4 | Memory & Context | ROUTE-04 | Phase 3 |
| 5 | Fallback & Resilience | ROUTE-05 | Phase 4 |
| 6 | Voice Pipeline | VOICE-01, VOICE-02, VOICE-03, VOICE-04, INFRA-01 | Phase 5 |
| 7 | Output Formatting | FORMAT-01, FORMAT-04 | Phase 5 |
| 8 | Interactive UI | FORMAT-02, FORMAT-03 | Phase 7 |
| 9 | Core Tools | TOOL-01, TOOL-02 | Phase 8 |
| 10 | Extended Tools | TOOL-03, TOOL-04 | Phase 9 |

---

## Phase 1: Infrastructure Foundation

**Goal:** Establish secure, stable infrastructure before any message handling

### Requirements
- **INFRA-02**: OLLAMA_KEEP_ALIVE=24h configured to prevent cold starts
- **INFRA-03**: Error handler workflow with Telegram alerts
- **INFRA-04**: Daily webhook re-registration to prevent silent failures
- **ROUTE-06**: All credentials stored in n8n credential system (no hardcoding)

### Success Criteria
1. **SC-1.1**: Ollama responds to API call after 30 minutes of inactivity (no cold start)
2. **SC-1.2**: Intentionally triggered error sends alert to Telegram within 60 seconds
3. **SC-1.3**: Zero hardcoded credentials in any workflow JSON (grep validation passes)
4. **SC-1.4**: Webhook health check scheduled cron job visible in n8n

**Plans:** 4 plans in 2 waves

Plans:
- [ ] 01-01-PLAN.md — Configure Ollama KEEP_ALIVE=24h in Docker (Wave 1)
- [ ] 01-02-PLAN.md — Update error handler with credentials (Wave 1)
- [ ] 01-03-PLAN.md — Create webhook health check cron (Wave 1)
- [ ] 01-04-PLAN.md — Audit and migrate all hardcoded credentials (Wave 2)

### Exit Gate
- [ ] All 4 success criteria pass
- [ ] No regressions in existing infrastructure

---

## Phase 2: Webhook & Message Intake

**Goal:** Telegram messages reliably reach n8n

### Requirements
- **ROUTE-01**: Supervisor workflow receives all Telegram messages via webhook
- **ROUTE-07**: Central queue handles Telegram's single-message-at-a-time constraint

### Success Criteria
1. **SC-2.1**: Text message to bot triggers webhook (n8n execution log shows payload)
2. **SC-2.2**: Rapid 3-message burst (sent within 2 seconds) all processed in order
3. **SC-2.3**: Webhook survives n8n restart (auto-registered on startup)
4. **SC-2.4**: Message queue prevents duplicate processing of same message

**Plans:** 4 plans in 3 waves

Plans:
- [ ] 02-01-PLAN.md — Configure webhook trigger and startup registration (Wave 1)
- [ ] 02-02-PLAN.md — Implement message deduplication via PostgreSQL (Wave 2)
- [ ] 02-03-PLAN.md — Add comprehensive logging (Wave 2)
- [ ] 02-04-PLAN.md — Integration testing and verification (Wave 3, checkpoint)

### Exit Gate
- [ ] 10 consecutive test messages processed without loss
- [ ] Message queue handles burst without duplicates

---

## Phase 3: AI Routing Core

**Goal:** Messages intelligently routed to appropriate workflows

### Requirements
- **ROUTE-02**: AI agent (Ollama qwen2.5:7b) routes messages to appropriate sub-workflow
- **ROUTE-03**: Natural language understanding (no strict command syntax required)

### Success Criteria
1. **SC-3.1**: "Check system health" routes to status tool (not keyword-matched)
2. **SC-3.2**: "Whats on my plate today" routes to ADHD Commander
3. **SC-3.3**: Gibberish input returns "I didn't understand" (graceful degradation)
4. **SC-3.4**: Routing decision logged with confidence score
5. **SC-3.5**: Average routing latency <3 seconds

**Plans:** 4 plans in 3 waves

Plans:
- [ ] 03-01-PLAN.md — Configure AI Agent with routing prompt and logging (Wave 1)
- [ ] 03-02-PLAN.md — Define tool schemas for all sub-workflows (Wave 1)
- [ ] 03-03-PLAN.md — Implement confidence threshold and fallback handling (Wave 2)
- [ ] 03-04-PLAN.md — Integration testing and latency validation (Wave 3, checkpoint)

### Exit Gate
- [ ] 18/20 test cases route correctly
- [ ] Confidence scores logged for audit
- [ ] Average routing latency <3 seconds

---

## Phase 4: Memory & Context

**Goal:** Conversations maintain context across messages

### Requirements
- **ROUTE-04**: PostgreSQL chat memory persists conversation context (13-14 messages)

### Success Criteria
1. **SC-4.1**: "Add that task" (referencing prior message) correctly identifies the task
2. **SC-4.2**: Context window shows last 13-14 messages in AI prompt
3. **SC-4.3**: Memory persists across n8n restarts
4. **SC-4.4**: Old messages automatically pruned beyond window

### Plans
1. Create PostgreSQL chat_memory table schema
2. Implement n8n Memory node with PostgreSQL backend
3. Configure context window size (13-14 messages)
4. Add automatic pruning for messages beyond window
5. Test context retrieval after restart
6. Validate memory doesn't exceed 4KB per conversation turn

### Exit Gate
- [ ] Multi-turn conversation test passes (3 messages with pronouns)
- [ ] Memory survives restart

---

## Phase 5: Fallback & Resilience

**Goal:** System degrades gracefully when primary AI unavailable

### Requirements
- **ROUTE-05**: Gemini Flash-Lite fallback when Ollama fails/times out

### Success Criteria
1. **SC-5.1**: Ollama timeout (>30s) triggers Gemini fallback automatically
2. **SC-5.2**: Gemini response quality matches Ollama for routing
3. **SC-5.3**: Fallback event logged with reason and timestamp
4. **SC-5.4**: Manual escalation prompt appears after 3 consecutive AI failures

### Plans
1. Add Ollama timeout detection (30 second threshold)
2. Integrate Gemini 2.5 Flash-Lite API via HTTP Request node
3. Create unified response format for both LLM outputs
4. Implement failure counter with escalation logic
5. Add fallback indicator in response ("via Gemini fallback")
6. Test Gemini rate limits (15 RPM, 1000 RPD)
7. Create quota exhaustion handler

### Exit Gate
- [ ] Simulated Ollama failure routes through Gemini
- [ ] No user-visible errors during fallback

---

## Phase 6: Voice Pipeline

**Goal:** Voice notes transcribed and processed like text

### Requirements
- **VOICE-01**: Detect voice notes from Telegram messages
- **VOICE-02**: Transcribe voice via faster-whisper container
- **VOICE-03**: Progressive status updates ("Transcribing..." then "Processing...")
- **VOICE-04**: Echo transcription back before executing command
- **INFRA-01**: faster-whisper Docker container added to compose stack

### Success Criteria
1. **SC-6.1**: Voice note (any duration <60s) triggers transcription pipeline
2. **SC-6.2**: User sees "Transcribing..." within 2 seconds of sending
3. **SC-6.3**: Transcription echoed: "You said: [transcription]"
4. **SC-6.4**: Transcribed text routes correctly (same as typed text)
5. **SC-6.5**: faster-whisper container healthy in docker-compose

### Plans
1. Add faster-whisper service to docker-compose.yml
2. Create voice detection node (check for voice field in Telegram payload)
3. Download voice file via Telegram API
4. Convert .oga to .ogg format if needed
5. Send to faster-whisper HTTP endpoint
6. Send progressive status messages
7. Echo transcription with confirmation
8. Route transcription through existing AI pipeline
9. Handle transcription failures gracefully

### Exit Gate
- [ ] 5 voice notes of varying lengths transcribed correctly
- [ ] Progressive updates visible in Telegram

---

## Phase 7: Output Formatting

**Goal:** All responses optimized for ADHD readability

### Requirements
- **FORMAT-01**: ADHD formatting (bold keywords, max 3 bullets, single next-step)
- **FORMAT-04**: TL;DR summary with expandable details

### Success Criteria
1. **SC-7.1**: Every response has bold keywords (at least 2 per message)
2. **SC-7.2**: Bullet lists never exceed 3 items
3. **SC-7.3**: "Next step:" line appears at end of actionable responses
4. **SC-7.4**: Long responses show TL;DR first, details collapsed

### Plans
1. Create output formatting utility workflow
2. Define ADHD format template with placeholders
3. Implement bullet truncation logic (top 3 by priority)
4. Add "Next step" extraction from AI response
5. Implement TL;DR + expandable pattern using Telegram HTML
6. Test formatting across all existing response types
7. Add formatting validation before send

### Exit Gate
- [ ] 10 sample responses all match ADHD format spec
- [ ] No wall-of-text responses

---

## Phase 8: Interactive UI

**Goal:** Critical actions require explicit confirmation

### Requirements
- **FORMAT-02**: Inline buttons for Yes/No confirmations
- **FORMAT-03**: Priority selector buttons (High/Medium/Low)

### Success Criteria
1. **SC-8.1**: Destructive actions show Yes/No buttons (not text prompt)
2. **SC-8.2**: Button press triggers correct callback workflow
3. **SC-8.3**: Priority buttons update task with selected priority
4. **SC-8.4**: Buttons expire after 5 minutes (prevent stale actions)

### Plans
1. Create callback query handler workflow
2. Implement Yes/No button template
3. Implement Priority selector template
4. Map callback_data to appropriate actions
5. Add button expiration logic
6. Test button interactions with real Telegram client
7. Handle button press on old/expired messages

### Exit Gate
- [ ] Full confirmation flow test: action -> buttons -> selection -> execution
- [ ] Expired button handled gracefully

---

## Phase 9: Core Tools

**Goal:** Essential automation tools available via Telegram

### Requirements
- **TOOL-01**: System Status - Check EC2, Docker, n8n, Ollama health
- **TOOL-02**: ADHD Commander - AI-selected task from Notion board

### Success Criteria
1. **SC-9.1**: "System status" returns EC2, Docker, n8n, Ollama health in <5s
2. **SC-9.2**: Health check shows green/yellow/red indicators
3. **SC-9.3**: "What should I work on?" returns single prioritized task
4. **SC-9.4**: ADHD Commander explains why task was selected

### Plans
1. Create System Status sub-workflow
2. Implement EC2 metrics check (CPU, memory, disk)
3. Implement Docker container health check
4. Implement Ollama API health check
5. Create ADHD Commander sub-workflow
6. Integrate Notion API for task board
7. Build task selection algorithm (energy level + deadline + priority)
8. Format outputs with health indicators
9. Add caching to prevent rate limiting

### Exit Gate
- [ ] Status check returns all 4 components healthy
- [ ] Commander returns actionable task with reasoning

---

## Phase 10: Extended Tools

**Goal:** Specialized tools for finance and security workflows

### Requirements
- **TOOL-03**: Finance Manager - Log transactions, track debt burn-down
- **TOOL-04**: Security Scan - Nmap/Nuclei scans with target confirmation

### Success Criteria
1. **SC-10.1**: "Log $50 for groceries" creates transaction record
2. **SC-10.2**: "Debt status" shows current balance and burn rate
3. **SC-10.3**: "Scan example.com" shows confirmation button before execution
4. **SC-10.4**: Scan results formatted with severity indicators
5. **SC-10.5**: Scans restricted to whitelisted targets only

### Plans
1. Create Finance Manager sub-workflow
2. Design transaction schema (amount, category, date, notes)
3. Implement debt tracking with $60K target
4. Build burn-down calculation (monthly average, projected exit date)
5. Create Security Scan sub-workflow
6. Implement target whitelist validation
7. Add confirmation flow for scans (FROM Phase 8)
8. Run Nmap via SSH to EC2
9. Format scan results for Telegram
10. Add rate limiting for scans

### Exit Gate
- [ ] Transaction logging end-to-end test
- [ ] Scan with confirmation flow on whitelisted target

---

## Requirement Coverage Matrix

| Requirement | Phase | Success Criteria |
|-------------|-------|------------------|
| ROUTE-01 | 2 | SC-2.1, SC-2.3 |
| ROUTE-02 | 3 | SC-3.1, SC-3.2 |
| ROUTE-03 | 3 | SC-3.1, SC-3.2, SC-3.3 |
| ROUTE-04 | 4 | SC-4.1, SC-4.2, SC-4.3 |
| ROUTE-05 | 5 | SC-5.1, SC-5.2 |
| ROUTE-06 | 1 | SC-1.3 |
| ROUTE-07 | 2 | SC-2.2, SC-2.4 |
| VOICE-01 | 6 | SC-6.1 |
| VOICE-02 | 6 | SC-6.1, SC-6.5 |
| VOICE-03 | 6 | SC-6.2 |
| VOICE-04 | 6 | SC-6.3 |
| FORMAT-01 | 7 | SC-7.1, SC-7.2, SC-7.3 |
| FORMAT-02 | 8 | SC-8.1, SC-8.2 |
| FORMAT-03 | 8 | SC-8.3 |
| FORMAT-04 | 7 | SC-7.4 |
| TOOL-01 | 9 | SC-9.1, SC-9.2 |
| TOOL-02 | 9 | SC-9.3, SC-9.4 |
| TOOL-03 | 10 | SC-10.1, SC-10.2 |
| TOOL-04 | 10 | SC-10.3, SC-10.4, SC-10.5 |
| INFRA-01 | 6 | SC-6.5 |
| INFRA-02 | 1 | SC-1.1 |
| INFRA-03 | 1 | SC-1.2 |
| INFRA-04 | 1 | SC-1.4 |

**Total Requirements:** 22
**Total Mapped:** 22
**Coverage:** 100%

---

## Critical Path

```
Phase 1 (Infrastructure)
    ↓
Phase 2 (Webhook)
    ↓
Phase 3 (AI Routing)
    ↓
Phase 4 (Memory)
    ↓
Phase 5 (Fallback) ←─── Can parallelize Phase 6 (Voice)
    ↓
Phase 7 (Formatting)
    ↓
Phase 8 (Interactive UI)
    ↓
Phase 9 (Core Tools)
    ↓
Phase 10 (Extended Tools)
```

**Parallelization Opportunity:** Phase 6 (Voice) can begin after Phase 5 starts, running concurrently with Phases 5-7.

---

## Risk Register

| Risk | Phase | Mitigation |
|------|-------|------------|
| Ollama OOM on t3.xlarge | 1 | Monitor memory, reduce context window |
| Gemini rate limit hit | 5 | Track quota, implement backoff |
| Webhook registration fails silently | 2 | Daily health check cron |
| Voice file format rejection | 6 | Convert .oga to .ogg |
| Telegram button callback timeout | 8 | Add expiration handling |

---

*Last updated: 2026-02-04*
*Next review: After Phase 1 completion*
