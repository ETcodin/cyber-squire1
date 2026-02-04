# Phase 07: Output Formatting - State Tracker

## Overview
Optimize all Telegram responses for ADHD readability with bold keywords, bullet truncation, and TL;DR summaries.

## Progress: 0/2 Plans Completed (0%)

---

## 07-01: ADHD Formatting Core ❌ NOT STARTED
**Status**: Pending
**Dependencies**: None
**Blocker**: None

### Tasks
- [ ] Create format_adhd_response.json workflow
- [ ] Implement bold keyword extraction
- [ ] Implement bullet truncation (max 3 items)
- [ ] Implement next-step extraction
- [ ] Assemble final formatted output

### Artifacts
- [ ] format_adhd_response.json workflow
- [ ] Test results with sample responses

---

## 07-02: TL;DR Expandable Format ❌ NOT STARTED
**Status**: Pending
**Dependencies**: 07-01
**Blocker**: None

### Tasks
- [ ] Define length threshold (300 chars)
- [ ] Generate AI-powered TL;DR summaries
- [ ] Implement Telegram spoiler syntax
- [ ] Apply ADHD formatting to both parts
- [ ] Add helpful hint for first-time users

### Artifacts
- [ ] format_tldr_expandable.json workflow
- [ ] TL;DR generation logic
- [ ] Telegram spoiler formatting

---

## Success Criteria (from ROADMAP.md)

1. **SC-7.1**: Every response has bold keywords (at least 2 per message)
2. **SC-7.2**: Bullet lists never exceed 3 items
3. **SC-7.3**: "Next step:" line appears at end of actionable responses
4. **SC-7.4**: Long responses show TL;DR first, details collapsed

---

## ADHD Formatting Specifications

### Bold Keywords
- 2-5 keywords per paragraph
- Priority: action verbs, numbers, status words
- Examples: **ready**, **16GB**, **failed**, **5 seconds**

### Bullet Lists
- Max 3 items visible
- If >3: show top 3 + "... and X more"
- Use emoji bullets for visual distinction:
  - ✅ Completed/success
  - ⚠️ Warning/attention
  - ❌ Error/failed
  - 📊 Status/metric
  - 🔄 In progress

### Next Step
- Only on actionable responses
- Format: "**Next step:** [specific action]"
- Imperative verb (Run, Check, Update, Create)

### TL;DR Format
- Trigger: messages >300 characters
- Summary: <100 characters, 1 sentence
- Details: hidden behind Telegram spoiler ||text||
- Hint: "(Tap gray box below for details)"

---

## Testing Checklist

### Basic Formatting (07-01)
- [ ] Short message (100 chars) has bold keywords
- [ ] Long message (400 chars) has bold keywords
- [ ] 5-item list truncated to 3 + "... and 2 more"
- [ ] Actionable message ends with "Next step:"
- [ ] Informational message has NO next-step line

### TL;DR Expandable (07-02)
- [ ] 250-char message uses standard format (no TL;DR)
- [ ] 400-char message uses TL;DR format
- [ ] TL;DR <100 chars
- [ ] Spoiler hides details until tapped
- [ ] Expanded details have ADHD formatting
- [ ] Hint appears for guidance

### Integration
- [ ] Apply to system status responses
- [ ] Apply to ADHD Commander responses
- [ ] Apply to error messages
- [ ] Apply to transcription echo messages

---

## Sample Test Cases

### Test Case 1: Short Actionable Response
Input:
```
The system is running normally. You should check the logs for any warnings.
```

Expected Output:
```
The system is **running** normally. You should check the logs for any warnings.

**Next step:** Check the logs for warnings
```

### Test Case 2: Long List Response
Input:
```
System health:
- PostgreSQL: healthy
- n8n: healthy
- Ollama: healthy
- Cloudflare tunnel: healthy
- Disk space: 78% used
- Memory: 45% used
- CPU: 12% used
```

Expected Output:
```
**System health:**
✅ PostgreSQL: **healthy**
✅ n8n: **healthy**
✅ Ollama: **healthy**
... and 4 more
```

### Test Case 3: Long Detailed Response (TL;DR)
Input:
```
Your ADHD Commander has analyzed your task board and selected the most important task for you right now. Based on your current energy level (medium), time of day (morning), and deadlines, you should work on "Implement faster-whisper integration". This task is marked as high priority and is due in 2 days. It's estimated to take 3 hours, which fits well into your morning focus window. The task is in your "In Progress" column, so you've already started it, which reduces context-switching overhead.
```

Expected Output:
```
**TL;DR:** Work on "Implement faster-whisper integration" (high priority, due in 2 days)

(Tap gray box below for details)

||Your ADHD Commander analyzed your task board and selected **"Implement faster-whisper integration"** based on your **medium** energy level, **morning** time slot, and **2-day** deadline. This **high priority** task takes **3 hours**, perfect for your morning focus window.

**Next step:** Continue working on faster-whisper integration||
```

---

## Notes

- **Telegram parse modes**: HTML is more reliable than MarkdownV2
- **Spoiler syntax**: ||text|| or <tg-spoiler>text</tg-spoiler>
- **Character limits**: Telegram max message length is 4096 characters
- **Bold escaping**: MarkdownV2 requires escaping special chars: \_\*\[\]\(\)\~\`\>\#\+\-\=\|\{\}\.\!

---

Last Updated: 2026-02-04 by Claude Sonnet 4.5
