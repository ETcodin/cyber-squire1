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

| Requirement | Phase | Success Criteria | Status |
|-------------|-------|------------------|--------|
| ROUTE-01 | Phase 2: Webhook & Message Intake | SC-2.1, SC-2.3 | Pending |
| ROUTE-02 | Phase 3: AI Routing Core | SC-3.1, SC-3.2 | Pending |
| ROUTE-03 | Phase 3: AI Routing Core | SC-3.1, SC-3.2, SC-3.3 | Pending |
| ROUTE-04 | Phase 4: Memory & Context | SC-4.1, SC-4.2, SC-4.3 | Pending |
| ROUTE-05 | Phase 5: Fallback & Resilience | SC-5.1, SC-5.2 | Pending |
| ROUTE-06 | Phase 1: Infrastructure Foundation | SC-1.3 | Pending |
| ROUTE-07 | Phase 2: Webhook & Message Intake | SC-2.2, SC-2.4 | Pending |
| VOICE-01 | Phase 6: Voice Pipeline | SC-6.1 | Pending |
| VOICE-02 | Phase 6: Voice Pipeline | SC-6.1, SC-6.5 | Pending |
| VOICE-03 | Phase 6: Voice Pipeline | SC-6.2 | Pending |
| VOICE-04 | Phase 6: Voice Pipeline | SC-6.3 | Pending |
| FORMAT-01 | Phase 7: Output Formatting | SC-7.1, SC-7.2, SC-7.3 | Pending |
| FORMAT-02 | Phase 8: Interactive UI | SC-8.1, SC-8.2 | Pending |
| FORMAT-03 | Phase 8: Interactive UI | SC-8.3 | Pending |
| FORMAT-04 | Phase 7: Output Formatting | SC-7.4 | Pending |
| TOOL-01 | Phase 9: Core Tools | SC-9.1, SC-9.2 | Pending |
| TOOL-02 | Phase 9: Core Tools | SC-9.3, SC-9.4 | Pending |
| TOOL-03 | Phase 10: Extended Tools | SC-10.1, SC-10.2 | Pending |
| TOOL-04 | Phase 10: Extended Tools | SC-10.3, SC-10.4, SC-10.5 | Pending |
| INFRA-01 | Phase 6: Voice Pipeline | SC-6.5 | Pending |
| INFRA-02 | Phase 1: Infrastructure Foundation | SC-1.1 | Pending |
| INFRA-03 | Phase 1: Infrastructure Foundation | SC-1.2 | Pending |
| INFRA-04 | Phase 1: Infrastructure Foundation | SC-1.4 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22 (100%)
- Success criteria defined: 34 total
- Unmapped: 0

**Phase Distribution:**
| Phase | Requirements Count |
|-------|-------------------|
| Phase 1: Infrastructure Foundation | 4 |
| Phase 2: Webhook & Message Intake | 2 |
| Phase 3: AI Routing Core | 2 |
| Phase 4: Memory & Context | 1 |
| Phase 5: Fallback & Resilience | 1 |
| Phase 6: Voice Pipeline | 5 |
| Phase 7: Output Formatting | 2 |
| Phase 8: Interactive UI | 2 |
| Phase 9: Core Tools | 2 |
| Phase 10: Extended Tools | 2 |

---
*Requirements defined: 2026-02-04*
*Last updated: 2026-02-04 after roadmap creation*
*See ROADMAP.md for detailed phase plans and success criteria*
