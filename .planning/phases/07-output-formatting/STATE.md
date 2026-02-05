# Phase 07: Output Formatting - State Tracker

## Overview
Optimize all Telegram responses for ADHD readability with bold keywords, bullet truncation, and TL;DR summaries.

## Progress: 2/2 Plans Completed (100%) ✓

---

## 07-01: ADHD Formatting Core ✓ COMPLETE
**Status**: Complete
**Dependencies**: None
**Completed**: 2026-02-05

### Tasks
- [x] Create ADHD formatting logic in Format Output node
- [x] Implement bold keyword extraction (status words, numbers with units)
- [x] Implement bullet truncation (max 3 items + "... and X more")
- [x] Implement next-step extraction (action detection)
- [x] Assemble final formatted output with MarkdownV2

### Artifacts
- [x] Format Output (ADHD) node in workflow_supervisor_agent.json
- [x] Bold keywords: healthy, running, error, failed, numbers, etc.
- [x] Emoji bullets: ✅ success, ❌ error, ⚠️ warning

---

## 07-02: TL;DR Expandable Format ✓ COMPLETE
**Status**: Complete
**Dependencies**: 07-01
**Completed**: 2026-02-05

### Tasks
- [x] Define length threshold (300 chars)
- [x] Generate TL;DR summary (first sentence or truncated)
- [x] Implement Telegram spoiler syntax (||text||)
- [x] Apply ADHD formatting to both summary and details
- [x] Add hint for first-time users ("Tap gray box for details")

### Artifacts
- [x] TL;DR generation in Format Output node
- [x] Spoiler syntax for expandable details
- [x] Threshold: 300 chars triggers TL;DR mode

---

## Success Criteria Status

1. **SC-7.1**: ✓ Bold keywords in all responses (status words, numbers)
2. **SC-7.2**: ✓ Bullet lists max 3 items + "... and X more"
3. **SC-7.3**: ✓ "Next step:" line for actionable responses
4. **SC-7.4**: ✓ Long responses (>300 chars) show TL;DR with spoiler

---

## Implementation Details

### Bold Keywords
Keywords automatically bolded:
- **Status words**: healthy, running, ready, complete, failed, error, warning, critical, down, offline, online, active, inactive, enabled, disabled, started, stopped, pending, processing
- **Numbers with units**: 16GB, 45%, 2.3s, etc.
- **Action verbs**: run, check, update, create, delete, restart, deploy, configure, etc.

### Bullet Truncation
```
Input (7 items):
- PostgreSQL: healthy
- n8n: healthy
- Ollama: healthy
- Cloudflare: healthy
- Disk: 78%
- Memory: 45%
- CPU: 12%

Output (3 + summary):
- ✅ PostgreSQL: **healthy**
- ✅ n8n: **healthy**
- ✅ Ollama: **healthy**
... and 4 more
```

### TL;DR Format
```
**TL;DR:** All systems healthy, no alerts

_(Tap gray box for details)_

||Full response text here with **bold** keywords...||
```

---

## Configuration

```json
"adhdConfig": {
  "tldrThreshold": 300,
  "maxTldrLength": 100,
  "maxBullets": 3,
  "parseMode": "MarkdownV2"
}
```

---

## Testing Notes

- MarkdownV2 requires escaping special characters
- Spoiler syntax ||text|| hides content until tapped
- Emoji bullets add visual hierarchy
- Next-step detection uses action verb patterns

---

Last Updated: 2026-02-05 by Claude Opus 4.5
