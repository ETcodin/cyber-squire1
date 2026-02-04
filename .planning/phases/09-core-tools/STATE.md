# Phase 09: Core Tools - State Tracker

## Overview
Implement essential automation tools: System Status and ADHD Commander.

## Progress: 0/2 Plans Completed (0%)

---

## 09-01: System Status Tool ❌ NOT STARTED
**Status**: Pending
**Dependencies**: None
**Blocker**: None

### Tasks
- [ ] Create system status workflow structure
- [ ] Implement EC2 metrics check
- [ ] Implement Docker container health check
- [ ] Implement n8n health check
- [ ] Implement Ollama health check
- [ ] Assemble and format status response

### Artifacts
- [ ] tool_system_status.json workflow
- [ ] SSH command implementations
- [ ] Health check test results

---

## 09-02: ADHD Commander Tool ❌ NOT STARTED
**Status**: Pending
**Dependencies**: None
**Blocker**: None

### Tasks
- [ ] Set up Notion API integration
- [ ] Extract task context for AI selection
- [ ] Implement AI selection algorithm
- [ ] Format ADHD Commander response
- [ ] Add optional energy level input
- [ ] Add caching to prevent rate limiting

### Artifacts
- [ ] tool_adhd_commander.json workflow
- [ ] Notion API integration
- [ ] Task selection AI prompt
- [ ] Cache implementation

---

## SQL Schema Requirements

### notion_task_cache table
```sql
CREATE TABLE IF NOT EXISTS notion_task_cache (
    id SERIAL PRIMARY KEY,
    tasks JSONB NOT NULL,
    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_task_cache_time ON notion_task_cache(fetched_at DESC);
```

---

## Success Criteria (from ROADMAP.md)

1. **SC-9.1**: "System status" returns EC2, Docker, n8n, Ollama health in <5s
2. **SC-9.2**: Health check shows green/yellow/red indicators
3. **SC-9.3**: "What should I work on?" returns single prioritized task
4. **SC-9.4**: ADHD Commander explains why task was selected

---

## System Status Specifications

### Health Indicators

**EC2 Metrics:**
- ✅ Green: CPU <50%, Memory <70%, Disk <80%
- ⚠️ Yellow: CPU 50-80%, Memory 70-85%, Disk 80-90%
- ❌ Red: CPU >80%, Memory >85%, Disk >90%

**Docker Containers:**
- ✅ All running: "5/5 containers running"
- ⚠️ Some issues: "4/5 containers running (1 restarting)"
- ❌ Critical: "<4/5 containers running"

**n8n Health:**
- ✅ Database responsive, workflows active
- ⚠️ Database slow (>5s response)
- ❌ Database unreachable

**Ollama Health:**
- ✅ Response time <3s
- ⚠️ Response time 3-10s
- ❌ Timeout or >10s

### Sample Output
```
**System Status**

✅ EC2: Healthy (CPU: 12%, Memory: 45%, Disk: 22%)
✅ Docker: 5/5 containers running
✅ n8n: Healthy (23 active workflows)
✅ Ollama: Healthy (2.3s response time)

**Overall:** All systems operational ✅
```

---

## ADHD Commander Specifications

### Task Selection Algorithm

Priority order:
1. **Deadline urgency**: Tasks due in <2 days
2. **In Progress status**: Reduce context switching
3. **Energy match**: Complex tasks for high energy, simple for low
4. **Time fit**: Estimated time fits current time block
5. **Priority level**: High > Medium > Low

### Energy Level Mapping

**High Energy:**
- Complex, challenging tasks
- Long estimated time (3+ hours)
- Deep focus work

**Medium Energy:**
- Moderate complexity
- 1-3 hour tasks
- Standard development work

**Low Energy:**
- Simple, quick wins
- Already-started tasks
- Admin/cleanup work

### Sample Output
```
**ADHD Commander**

**Work on:** Implement faster-whisper integration

**Why:** High priority task due in 2 days, already in progress, fits your morning focus window

**Details:**
• Priority: High
• Deadline: Feb 6
• Estimated time: 3 hours

[ View in Notion 🔗 ]

**Next step:** Open Notion and continue this task
```

---

## Testing Checklist

### System Status (09-01)
- [ ] Command "System status" triggers workflow
- [ ] All 4 components checked (EC2, Docker, n8n, Ollama)
- [ ] Response time <5 seconds
- [ ] Health indicators accurate (✅ ⚠️ ❌)
- [ ] Simulated failure detected (stop container)
- [ ] ADHD formatting applied

### ADHD Commander (09-02)
- [ ] Command "What should I work on?" triggers workflow
- [ ] Single task returned (not a list)
- [ ] Explanation provided
- [ ] Notion link opens correct task
- [ ] Energy level "high" affects selection
- [ ] Energy level "low" affects selection
- [ ] Cache used on second request within 5 min
- [ ] Cache refreshed after 5 min

---

## Integration Points

### With AI Routing (Phase 3)
- System Status routed via "system", "status", "health" keywords
- ADHD Commander routed via "work on", "task", "what should I do"

### With Output Formatting (Phase 7)
- Both tools use ADHD formatting (bold keywords, max 3 bullets)
- Both tools include "Next step" line
- System Status may trigger TL;DR if verbose

### With Interactive UI (Phase 8)
- System Status could add "Restart service" buttons on failures
- ADHD Commander includes Notion URL button

---

## Notes

- **SSH access**: Both tools require SSH credentials for EC2
- **Notion API**: Rate limit 3 requests/second, caching essential
- **Ollama health**: Also validates KEEP_ALIVE from Phase 1
- **Response time**: <5s requirement means parallel health checks
- **Fallback**: If Notion API fails, gracefully degrade with error message

---

Last Updated: 2026-02-04 by Claude Sonnet 4.5
