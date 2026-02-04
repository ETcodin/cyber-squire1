# Phases 6-10 Implementation Summary

**Created:** 2026-02-04
**Author:** Claude Sonnet 4.5
**Status:** Planning Complete ✅

---

## Executive Summary

Successfully created comprehensive implementation plans for Phases 6-10 of the Cyber-Squire Telegram Router project. These phases transform the basic message routing system into a full-featured ADHD-optimized productivity assistant with voice transcription, interactive UI, and specialized automation tools.

**Deliverables:**
- **13 detailed PLAN.md files** with step-by-step implementation tasks
- **5 STATE.md files** tracking progress and requirements
- **1 OVERVIEW.md** summarizing all phases
- **8 SQL schemas** for database tables

---

## Plan Breakdown

### Phase 6: Voice Pipeline (4 plans)
Voice notes transcribed via faster-whisper and processed like text messages.

1. **06-01-PLAN.md**: faster-whisper Docker Container
   - Add faster-whisper service to docker-compose.yaml
   - Deploy container and verify health
   - Test transcription API

2. **06-02-PLAN.md**: Voice Detection & Download
   - Create voice_handler.json workflow
   - Detect voice messages from Telegram
   - Download .oga files via Telegram API
   - Send "Transcribing..." status message

3. **06-03-PLAN.md**: Transcription Integration
   - Convert audio format if needed
   - Send to faster-whisper API
   - Echo transcription: "You said: [text]"
   - Route to AI pipeline

4. **06-04-PLAN.md**: Error Handling & Edge Cases
   - Duration validation (max 60s)
   - Transcription failure handling
   - Empty transcription detection
   - Progress indicators for long notes
   - Database logging

**Key Success Criteria:**
- Voice note triggers transcription within 2 seconds (SC-6.2)
- Transcription echoed before executing command (SC-6.3)
- Transcribed text routes identically to typed text (SC-6.4)

---

### Phase 7: Output Formatting (2 plans)
All responses optimized for ADHD readability with bold keywords and TL;DR summaries.

1. **07-01-PLAN.md**: ADHD Formatting Core
   - Bold keyword extraction (2-5 per message)
   - Bullet truncation (max 3 items)
   - Next-step extraction for actionable messages
   - Reusable format_adhd_response.json workflow

2. **07-02-PLAN.md**: TL;DR Expandable Format
   - Length threshold: 300 characters
   - AI-generated TL;DR (<100 chars)
   - Telegram spoiler syntax for expandable details
   - Helpful hint: "(Tap gray box below for details)"

**Key Success Criteria:**
- Every response has bold keywords (SC-7.1)
- Bullet lists max 3 items (SC-7.2)
- Actionable responses end with "Next step:" (SC-7.3)
- Long responses show TL;DR first (SC-7.4)

---

### Phase 8: Interactive UI (3 plans)
Critical actions require explicit confirmation via inline buttons.

1. **08-01-PLAN.md**: Callback Handler Foundation
   - Register callback_query webhook
   - Parse callback data (format: "action:param1:param2")
   - Button expiration check (5 minutes)
   - Immediate callback acknowledgment
   - Database logging (button_interactions table)

2. **08-02-PLAN.md**: Button Templates
   - Yes/No confirmation template: [ ✅ Yes ] [ ❌ No ]
   - Priority selector: [ 🔴 High ] [ 🟡 Medium ] [ 🟢 Low ]
   - Custom multi-row layouts
   - URL button support (links to Notion, GitHub, etc.)

3. **08-03-PLAN.md**: Workflow Integration
   - Security Scan confirmation flow
   - Task creation priority selector
   - Destructive operation confirmations
   - Callback routing for all actions
   - Button analytics (decision rates, time-to-decision)

**Key Success Criteria:**
- Destructive actions show Yes/No buttons (SC-8.1)
- Button press triggers correct workflow (SC-8.2)
- Priority buttons update task (SC-8.3)
- Buttons expire after 5 minutes (SC-8.4)

---

### Phase 9: Core Tools (2 plans)
Essential automation tools: System Status and ADHD Commander.

1. **09-01-PLAN.md**: System Status Tool
   - EC2 metrics check (CPU, memory, disk)
   - Docker container health (all 5 containers)
   - n8n health (database + workflow count)
   - Ollama health (API response time)
   - Formatted response with ✅ ⚠️ ❌ indicators
   - Response time: <5 seconds

2. **09-02-PLAN.md**: ADHD Commander Tool
   - Notion API integration (task board)
   - Task context extraction (priority, deadline, time estimate)
   - AI-powered selection algorithm (energy level + deadline + context-switching)
   - Energy level personalization (high/medium/low)
   - Task caching (5-minute TTL to prevent rate limiting)
   - Notion link button for selected task

**Key Success Criteria:**
- "System status" returns all 4 components in <5s (SC-9.1, SC-9.2)
- "What should I work on?" returns single task (SC-9.3)
- ADHD Commander explains selection reasoning (SC-9.4)

---

### Phase 10: Extended Tools (2 plans)
Specialized tools for finance tracking and security scanning.

1. **10-01-PLAN.md**: Finance Manager
   - Transaction database schema (transactions, debt_tracking)
   - NLP parsing: "Log $50 for groceries" → amount, category, description
   - Debt burn-down tracking ($60K → $0 goal)
   - Monthly burn rate calculation (3-month average)
   - Projected payoff date calculation
   - Visual progress bar: [▓▓▓▓▓▓░░░░]
   - Spending summary (last 7 days, top 3 categories)

2. **10-02-PLAN.md**: Security Scanner
   - Target whitelist (allowed_scan_targets table)
   - Target validation (reject non-whitelisted)
   - Confirmation flow: "Confirm scan of X?" [ ✅ Yes ] [ ❌ No ]
   - Nmap integration (port scan)
   - Nuclei integration (vulnerability scan)
   - Severity indicators: 🔴 Critical, 🟠 High, 🟡 Medium, 🟢 Low
   - Rate limiting (1 scan/hour/target, 5 scans/day/user)
   - Scan history logging

**Key Success Criteria:**
- "Log $50 for groceries" creates transaction (SC-10.1)
- "Debt status" shows balance and burn rate (SC-10.2)
- "Scan X" requires confirmation (SC-10.3)
- Scan results show severity indicators (SC-10.4)
- Only whitelisted targets allowed (SC-10.5)

---

## Database Schemas Created

### Phase 6: voice_transcriptions
```sql
CREATE TABLE voice_transcriptions (
    id SERIAL PRIMARY KEY,
    message_id BIGINT UNIQUE NOT NULL,
    user_id BIGINT NOT NULL,
    duration INTEGER NOT NULL,
    transcription_time INTEGER,
    transcription_text TEXT,
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Phase 8: button_interactions
```sql
CREATE TABLE button_interactions (
    id SERIAL PRIMARY KEY,
    callback_query_id VARCHAR(255) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL,
    action VARCHAR(100) NOT NULL,
    params JSONB,
    button_age_seconds INTEGER NOT NULL,
    is_expired BOOLEAN DEFAULT false,
    decision VARCHAR(10),
    time_to_decision INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Phase 9: notion_task_cache
```sql
CREATE TABLE notion_task_cache (
    id SERIAL PRIMARY KEY,
    tasks JSONB NOT NULL,
    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Phase 10: Finance Manager
```sql
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    category VARCHAR(100),
    description TEXT,
    transaction_date DATE DEFAULT CURRENT_DATE,
    is_debt_payment BOOLEAN DEFAULT false,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE debt_tracking (
    id SERIAL PRIMARY KEY,
    total_debt DECIMAL(10, 2) NOT NULL,
    current_balance DECIMAL(10, 2),
    monthly_burn_rate DECIMAL(10, 2),
    projected_payoff_date DATE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Phase 10: Security Scanner
```sql
CREATE TABLE allowed_scan_targets (
    id SERIAL PRIMARY KEY,
    target VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    owner VARCHAR(100),
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE scan_history (
    id SERIAL PRIMARY KEY,
    target VARCHAR(255) NOT NULL,
    scan_type VARCHAR(50) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR(20),
    findings_count INTEGER,
    results JSONB,
    user_id BIGINT
);
```

---

## Workflow Files to be Created

### Phase 6
- `COREDIRECTIVE_ENGINE/workflows/voice_handler.json`

### Phase 7
- `COREDIRECTIVE_ENGINE/workflows/format_adhd_response.json`
- `COREDIRECTIVE_ENGINE/workflows/format_tldr_expandable.json`

### Phase 8
- `COREDIRECTIVE_ENGINE/workflows/callback_handler.json`
- `COREDIRECTIVE_ENGINE/workflows/button_templates.json`

### Phase 9
- `COREDIRECTIVE_ENGINE/workflows/tool_system_status.json`
- `COREDIRECTIVE_ENGINE/workflows/tool_adhd_commander.json`

### Phase 10
- `COREDIRECTIVE_ENGINE/workflows/tool_finance_manager.json`
- `COREDIRECTIVE_ENGINE/workflows/tool_security_scan.json`

**Total Workflows:** 9 new workflows

---

## SQL Schema Files to be Created

### Phase 6
- `COREDIRECTIVE_ENGINE/sql/voice_schema.sql`

### Phase 8
- `COREDIRECTIVE_ENGINE/sql/button_interactions_schema.sql`

### Phase 9
- `COREDIRECTIVE_ENGINE/sql/notion_cache_schema.sql`

### Phase 10
- `COREDIRECTIVE_ENGINE/sql/finance_schema.sql`
- `COREDIRECTIVE_ENGINE/sql/security_whitelist.sql`

**Total SQL Files:** 5 new schema files

---

## External Dependencies

### Phase 6: Voice Pipeline
- **faster-whisper-server**: Docker container for voice transcription
  - Image: `fedirz/faster-whisper-server:latest-cpu`
  - Model: base (good balance of speed vs accuracy)
  - Port: 8000

### Phase 9: ADHD Commander
- **Notion API**: Task board integration
  - Rate limit: 3 requests/second
  - Requires: Notion API key + database ID

### Phase 10: Security Scanner
- **Nmap**: Port scanning tool
  - Install: `sudo yum install nmap -y`
  - Command: `nmap -sV -T4 --top-ports 100 <target>`

- **Nuclei**: Vulnerability scanner
  - Install: Download from GitHub releases
  - Command: `nuclei -u <target> -severity critical,high -json`

---

## Implementation Order Recommendation

### Sequential (must be in order)
1. **Phase 7** → **Phase 8** → **Phase 10-02**
   - Phase 8 depends on Phase 7 (formatting for button messages)
   - Phase 10-02 depends on Phase 8 (confirmation buttons for security scans)

### Parallel Opportunities
- **Phase 6** can run independently (voice pipeline doesn't depend on other phases)
- **Phase 9** can run independently (core tools standalone)
- **Phase 10-01** can run independently (finance manager doesn't need buttons)

### Suggested Timeline
1. **Week 1**: Phase 6 (voice pipeline) + Phase 7 (formatting)
2. **Week 2**: Phase 8 (interactive UI)
3. **Week 3**: Phase 9 (core tools)
4. **Week 4**: Phase 10 (extended tools)

---

## Testing Strategy

### Unit Testing (per plan)
- Each plan includes verification steps
- Test individual components before integration

### Integration Testing (per phase)
- STATE.md includes comprehensive testing checklist
- Test end-to-end flows

### User Acceptance Testing
- Voice Pipeline: 5 voice notes of varying lengths
- Output Formatting: 10 sample responses across all types
- Interactive UI: Full confirmation flow (action → buttons → selection → execution)
- System Status: Check all 4 components healthy
- ADHD Commander: Task selection with different energy levels
- Finance Manager: Transaction logging → debt status
- Security Scanner: Scan with confirmation on whitelisted target

---

## Risk Mitigation

### Phase 6 Risks
- **Risk**: faster-whisper container OOM on t3.xlarge
- **Mitigation**: Using CPU version (not GPU), base model (not large)

### Phase 8 Risks
- **Risk**: Button callback timeout (30s limit)
- **Mitigation**: Immediate acknowledgment, then async execution

### Phase 9 Risks
- **Risk**: Notion API rate limit exceeded
- **Mitigation**: 5-minute task cache, max 1 request per 5 min

### Phase 10 Risks
- **Risk**: Unauthorized security scans
- **Mitigation**: Whitelist validation before ANY scan execution
- **Mitigation**: Confirmation buttons for double verification
- **Mitigation**: Rate limiting (1/hour/target)

---

## Success Metrics

### Voice Pipeline
- 95%+ transcription accuracy for clear speech
- <2 second latency from voice note to "Transcribing..." message

### Output Formatting
- 100% of responses have ADHD formatting (bold keywords, max 3 bullets)
- 0 wall-of-text responses (all long messages use TL;DR)

### Interactive UI
- 100% of destructive actions require confirmation
- <1% expired button clicks (5-minute window sufficient)

### Core Tools
- System status response time: <5 seconds
- ADHD Commander task selection accuracy: 80%+ user satisfaction

### Extended Tools
- Finance logging: <5 seconds from message to confirmation
- Security scans: 0 unauthorized targets scanned

---

## Files Created in This Session

```
.planning/phases/
├── 06-voice-pipeline/
│   ├── 06-01-PLAN.md ✅
│   ├── 06-02-PLAN.md ✅
│   ├── 06-03-PLAN.md ✅
│   ├── 06-04-PLAN.md ✅
│   └── STATE.md ✅
├── 07-output-formatting/
│   ├── 07-01-PLAN.md ✅
│   ├── 07-02-PLAN.md ✅
│   └── STATE.md ✅
├── 08-interactive-ui/
│   ├── 08-01-PLAN.md ✅
│   ├── 08-02-PLAN.md ✅
│   ├── 08-03-PLAN.md ✅
│   └── STATE.md ✅
├── 09-core-tools/
│   ├── 09-01-PLAN.md ✅
│   ├── 09-02-PLAN.md ✅
│   └── STATE.md ✅
├── 10-extended-tools/
│   ├── 10-01-PLAN.md ✅
│   ├── 10-02-PLAN.md ✅
│   └── STATE.md ✅
├── PHASES_06-10_OVERVIEW.md ✅
└── PHASES_06-10_SUMMARY.md ✅ (this file)
```

**Total Files:** 20 files created

---

## Next Steps

### Immediate Actions
1. Review all 13 PLAN.md files for accuracy and completeness
2. Validate SQL schemas match database naming conventions
3. Confirm external dependencies (Nmap, Nuclei, Notion API) are accessible

### Pre-Implementation Setup
1. Install Nmap on EC2: `sudo yum install nmap -y`
2. Install Nuclei on EC2 (download from GitHub releases)
3. Set up Notion API integration (create integration, get API key)
4. Create Telegram credential in n8n (for callback webhook)

### Phase 6 Start
1. Execute 06-01-PLAN.md: Add faster-whisper to docker-compose.yaml
2. Deploy faster-whisper container to EC2
3. Verify health check endpoint
4. Test transcription with sample audio

### Tracking Progress
- Update STATE.md files as plans complete
- Create SUMMARY.md files after each plan
- Track success criteria validation

---

## Conclusion

Phases 6-10 planning is **complete and comprehensive**. All plans include:
- Clear objectives
- Detailed implementation tasks
- Verification steps
- Success criteria
- Database schemas
- Integration points

The system is designed with ADHD users in mind:
- Voice input (reduce typing friction)
- Bold keywords (improve scannability)
- Max 3 bullets (prevent overwhelm)
- Confirmation buttons (prevent mistakes)
- Single task selection (combat decision paralysis)
- Instant system status (reduce context switching)

**Ready for implementation.**

---

**Created:** 2026-02-04
**Last Updated:** 2026-02-04
**Document Version:** 1.0
**Author:** Claude Sonnet 4.5
