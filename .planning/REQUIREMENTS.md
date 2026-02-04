# Requirements: Cyber-Squire Telegram Router

**Defined:** 2026-02-04
**Core Value:** Every interaction through Telegram must route to the right workflow with zero manual overhead.

## v1 Requirements

### Routing & Core

- [ ] **ROUTE-01**: Supervisor workflow receives all Telegram messages via webhook
- [ ] **ROUTE-02**: AI agent (Ollama qwen2.5:7b) routes messages to appropriate sub-workflow
- [ ] **ROUTE-03**: Natural language understanding (no strict command syntax required)
- [ ] **ROUTE-04**: PostgreSQL chat memory persists conversation context (13-14 messages)
- [ ] **ROUTE-05**: Gemini Flash-Lite fallback when Ollama fails/times out
- [ ] **ROUTE-06**: All credentials stored in n8n credential system (no hardcoding)
- [ ] **ROUTE-07**: Central queue handles Telegram's single-message-at-a-time constraint

### Voice Support

- [ ] **VOICE-01**: Detect voice notes from Telegram messages
- [ ] **VOICE-02**: Transcribe voice via faster-whisper container
- [ ] **VOICE-03**: Progressive status updates ("Transcribing..." → "Processing...")
- [ ] **VOICE-04**: Echo transcription back before executing command

### Output Formatting

- [ ] **FORMAT-01**: ADHD formatting (bold keywords, max 3 bullets, single next-step)
- [ ] **FORMAT-02**: Inline buttons for Yes/No confirmations
- [ ] **FORMAT-03**: Priority selector buttons (🔴 High / 🟡 Medium / 🟢 Low)
- [ ] **FORMAT-04**: TL;DR summary with expandable details

### Agent Tools

- [ ] **TOOL-01**: System Status — Check EC2, Docker, n8n, Ollama health
- [ ] **TOOL-02**: ADHD Commander — AI-selected task from Notion board
- [ ] **TOOL-03**: Finance Manager — Log transactions, track debt burn-down
- [ ] **TOOL-04**: Security Scan — Nmap/Nuclei scans with target confirmation

### Infrastructure

- [ ] **INFRA-01**: faster-whisper Docker container added to compose stack
- [ ] **INFRA-02**: OLLAMA_KEEP_ALIVE=24h configured to prevent cold starts
- [ ] **INFRA-03**: Error handler workflow with Telegram alerts
- [ ] **INFRA-04**: Daily webhook re-registration to prevent silent failures

## v2 Requirements

### GovCon Integration
- **GOVCON-01**: SAM.gov bid monitoring with keyword filters
- **GOVCON-02**: Georgia Bidding alerts
- **GOVCON-03**: SOW analysis against credentials (fit score)
- **GOVCON-04**: Auto-draft inquiry for GREEN-lit bids

### Content Engine
- **CONTENT-01**: YouTube script generation from security topics
- **CONTENT-02**: Thumbnail idea suggestions
- **CONTENT-03**: SEO keyword extraction

### Advanced Features
- **ADV-01**: Quiet hours (no notifications 10pm-8am)
- **ADV-02**: Low-uptime mode (passive tasks only)
- **ADV-03**: Voice command shortcuts

## Out of Scope

| Feature | Reason |
|---------|--------|
| Claude API integration | Using subscription only, no API billing |
| Multi-user support | Single principal system |
| Mobile app | Telegram is the interface |
| Real-time streaming | Telegram API doesn't support it |
| Web dashboard | Notion serves as data layer |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ROUTE-01 | Phase 1 | Pending |
| ROUTE-02 | Phase 1 | Pending |
| ROUTE-03 | Phase 1 | Pending |
| ROUTE-04 | Phase 1 | Pending |
| ROUTE-05 | Phase 2 | Pending |
| ROUTE-06 | Phase 1 | Pending |
| ROUTE-07 | Phase 1 | Pending |
| VOICE-01 | Phase 2 | Pending |
| VOICE-02 | Phase 2 | Pending |
| VOICE-03 | Phase 2 | Pending |
| VOICE-04 | Phase 2 | Pending |
| FORMAT-01 | Phase 1 | Pending |
| FORMAT-02 | Phase 3 | Pending |
| FORMAT-03 | Phase 3 | Pending |
| FORMAT-04 | Phase 3 | Pending |
| TOOL-01 | Phase 4 | Pending |
| TOOL-02 | Phase 4 | Pending |
| TOOL-03 | Phase 5 | Pending |
| TOOL-04 | Phase 5 | Pending |
| INFRA-01 | Phase 2 | Pending |
| INFRA-02 | Phase 1 | Pending |
| INFRA-03 | Phase 1 | Pending |
| INFRA-04 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-04*
*Last updated: 2026-02-04 after initial definition*
