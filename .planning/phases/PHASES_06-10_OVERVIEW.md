# Phases 6-10 Overview

**Created:** 2026-02-04
**Status:** Planning Complete, Implementation Pending

---

## Summary

Phases 6-10 complete the Cyber-Squire Telegram Router with advanced features:
- **Phase 6**: Voice note transcription via faster-whisper
- **Phase 7**: ADHD-optimized output formatting
- **Phase 8**: Interactive UI with confirmation buttons
- **Phase 9**: Core tools (System Status, ADHD Commander)
- **Phase 10**: Extended tools (Finance Manager, Security Scanner)

Total plans created: **13 plans** across 5 phases

---

## Phase 6: Voice Pipeline (4 plans)

**Goal:** Voice notes transcribed and processed like text

### Plans
1. **06-01**: faster-whisper Docker Container
   - Add faster-whisper service to compose stack
   - Deploy and verify health check
   - Test transcription API

2. **06-02**: Voice Detection & Download
   - Create voice handler workflow
   - Detect voice messages from Telegram
   - Download voice files via Telegram API
   - Add "Transcribing..." status message

3. **06-03**: Transcription Integration
   - Send audio to faster-whisper API
   - Echo transcription to user
   - Route transcribed text to AI pipeline

4. **06-04**: Error Handling & Edge Cases
   - Duration validation (max 60s)
   - Transcription error handling
   - Empty transcription detection
   - Progress indicators for long notes
   - Database logging

### Key Deliverables
- faster-whisper container in docker-compose.yaml
- voice_handler.json workflow
- voice_transcriptions database table
- End-to-end: voice note → transcription → AI response

---

## Phase 7: Output Formatting (2 plans)

**Goal:** All responses optimized for ADHD readability

### Plans
1. **07-01**: ADHD Formatting Core
   - Bold keyword extraction (2-5 per message)
   - Bullet truncation (max 3 items)
   - Next-step extraction for actionable messages
   - Reusable formatting workflow

2. **07-02**: TL;DR Expandable Format
   - Length threshold (300 chars)
   - AI-generated TL;DR summaries (<100 chars)
   - Telegram spoiler syntax for expandable details
   - Helpful hint for first-time users

### Key Deliverables
- format_adhd_response.json workflow
- format_tldr_expandable.json workflow
- ADHD formatting applied to all responses
- TL;DR for long messages (>300 chars)

---

## Phase 8: Interactive UI (3 plans)

**Goal:** Critical actions require explicit confirmation

### Plans
1. **08-01**: Callback Handler Foundation
   - Register callback_query webhook
   - Parse callback data and route
   - Button expiration check (5 minutes)
   - Callback acknowledgment
   - Database logging

2. **08-02**: Button Templates
   - Yes/No confirmation template
   - Priority selector template (High/Medium/Low)
   - Custom multi-row button support
   - URL button support

3. **08-03**: Workflow Integration
   - Add confirmation to Security Scan
   - Add priority selector to task creation
   - Retrofit destructive operations with confirmations
   - Callback routing for all actions
   - Button analytics

### Key Deliverables
- callback_handler.json workflow
- button_templates.json workflow
- button_interactions database table
- Confirmation buttons for critical actions

---

## Phase 9: Core Tools (2 plans)

**Goal:** Essential automation tools via Telegram

### Plans
1. **09-01**: System Status Tool
   - EC2 metrics check (CPU, memory, disk)
   - Docker container health check
   - n8n health check
   - Ollama health check with response time
   - Formatted status response (<5s)

2. **09-02**: ADHD Commander Tool
   - Notion API integration
   - Task context extraction
   - AI-powered task selection algorithm
   - Energy level personalization
   - Task caching (5 min TTL)

### Key Deliverables
- tool_system_status.json workflow
- tool_adhd_commander.json workflow
- notion_task_cache database table
- "System status" command
- "What should I work on?" command

---

## Phase 10: Extended Tools (2 plans)

**Goal:** Specialized tools for finance and security

### Plans
1. **10-01**: Finance Manager
   - Transaction database schema
   - NLP transaction parsing
   - Debt burn-down tracking ($60K goal)
   - Spending summary by category
   - Visual progress bar

2. **10-02**: Security Scanner
   - Target whitelist schema
   - Target validation
   - Confirmation flow (from Phase 8)
   - Nmap port scan integration
   - Nuclei vulnerability scan integration
   - Severity indicators (🔴 🟠 🟡 🟢)
   - Rate limiting (1 per hour per target)

### Key Deliverables
- tool_finance_manager.json workflow
- tool_security_scan.json workflow
- transactions, debt_tracking tables
- allowed_scan_targets, scan_history tables
- "Log $X for Y" command
- "Debt status" command
- "Scan <target>" command

---

## Database Schema Summary

### Phase 6: Voice Pipeline
- `voice_transcriptions` (message_id, duration, transcription_text, success, error_message)

### Phase 8: Interactive UI
- `button_interactions` (callback_query_id, action, params, decision, time_to_decision)

### Phase 9: Core Tools
- `notion_task_cache` (tasks JSONB, fetched_at)

### Phase 10: Extended Tools
- `transactions` (amount, category, description, is_debt_payment)
- `debt_tracking` (current_balance, monthly_burn_rate, projected_payoff_date)
- `allowed_scan_targets` (target, description, owner)
- `scan_history` (target, scan_type, findings_count, results JSONB)

---

## Dependencies

### External Services
- **Notion API**: ADHD Commander task selection
- **Telegram Bot API**: All interactions, callbacks, buttons
- **faster-whisper**: Voice transcription (self-hosted)

### Phase Dependencies
- Phase 8 must complete before Phase 10 (security scan needs confirmation buttons)
- Phase 7 should complete before Phases 9-10 (formatting for tool outputs)
- Phase 6 can run in parallel with Phases 7-8

### System Requirements
- **EC2**: SSH access for system status checks and security scans
- **Nmap**: Install on EC2 for port scanning
- **Nuclei**: Install on EC2 for vulnerability scanning
- **Docker**: faster-whisper container deployment

---

## Success Criteria Coverage

| Requirement | Phase | Success Criteria |
|-------------|-------|------------------|
| VOICE-01-04 | 6 | SC-6.1, SC-6.2, SC-6.3, SC-6.4 |
| INFRA-01 | 6 | SC-6.5 |
| FORMAT-01 | 7 | SC-7.1, SC-7.2, SC-7.3 |
| FORMAT-04 | 7 | SC-7.4 |
| FORMAT-02 | 8 | SC-8.1, SC-8.2 |
| FORMAT-03 | 8 | SC-8.3 |
| TOOL-01 | 9 | SC-9.1, SC-9.2 |
| TOOL-02 | 9 | SC-9.3, SC-9.4 |
| TOOL-03 | 10 | SC-10.1, SC-10.2 |
| TOOL-04 | 10 | SC-10.3, SC-10.4, SC-10.5 |

**Total Requirements Covered:** 10
**Total Success Criteria:** 19

---

## Implementation Notes

### Phase 6 Notes
- faster-whisper base model provides good balance (speed vs accuracy)
- CPU version avoids GPU conflicts with Ollama
- Telegram voice notes are always .oga (Ogg/Opus format)
- 60-second duration limit enforces brevity

### Phase 7 Notes
- Telegram HTML more reliable than MarkdownV2
- Spoiler syntax: `||text||` or `<tg-spoiler>text</tg-spoiler>`
- 300-character threshold for TL;DR trigger
- Ollama used for AI summarization (fast, local)

### Phase 8 Notes
- Callback buttons expire after 5 minutes
- Must acknowledge callback within 30 seconds
- Max 8 buttons per row, max 100 chars in callback_data
- Emoji buttons improve scannability (✅ ❌ 🔴 🟡 🟢)

### Phase 9 Notes
- System status checks run in parallel (<5s total)
- Notion API rate limit: 3 requests/second
- Task caching essential (5-minute TTL)
- Energy level affects task complexity selection

### Phase 10 Notes
- Finance tracking: USD with 2 decimal precision
- Security scans: whitelist prevents abuse
- Rate limiting: 1 scan/hour/target, 5 scans/day/user
- Nmap timeout: 5 minutes for slow scans

---

## Next Steps

1. **Review Plans**: Validate all 13 plans with stakeholder
2. **Prioritize**: Determine execution order (suggested: 6 → 7 → 8 → 9 → 10)
3. **Dependencies**: Install Nmap, Nuclei on EC2 before Phase 10
4. **Database**: Run all SQL schema scripts
5. **Execute**: Begin with Phase 6, Plan 01 (faster-whisper container)

---

## File Structure

```
.planning/phases/
├── 06-voice-pipeline/
│   ├── 06-01-PLAN.md (faster-whisper container)
│   ├── 06-02-PLAN.md (voice detection & download)
│   ├── 06-03-PLAN.md (transcription integration)
│   ├── 06-04-PLAN.md (error handling)
│   └── STATE.md
├── 07-output-formatting/
│   ├── 07-01-PLAN.md (ADHD formatting core)
│   ├── 07-02-PLAN.md (TL;DR expandable)
│   └── STATE.md
├── 08-interactive-ui/
│   ├── 08-01-PLAN.md (callback handler)
│   ├── 08-02-PLAN.md (button templates)
│   ├── 08-03-PLAN.md (workflow integration)
│   └── STATE.md
├── 09-core-tools/
│   ├── 09-01-PLAN.md (system status)
│   ├── 09-02-PLAN.md (ADHD commander)
│   └── STATE.md
├── 10-extended-tools/
│   ├── 10-01-PLAN.md (finance manager)
│   ├── 10-02-PLAN.md (security scanner)
│   └── STATE.md
└── PHASES_06-10_OVERVIEW.md (this file)
```

---

Last Updated: 2026-02-04 by Claude Sonnet 4.5
