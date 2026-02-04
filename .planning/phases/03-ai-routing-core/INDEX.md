# Phase 3: AI Routing Core — Planning Index

**Created:** 2026-02-04
**Status:** Ready for execution
**Total Plans:** 4 (across 3 waves)

---

## Plan Files

| Plan | Name | Wave | Type | Dependencies | Key Outputs |
|------|------|------|------|--------------|-------------|
| **03-01** | AI Agent Routing Configuration | 1 | Execute | None | Enhanced prompt, routing logs, test cases |
| **03-02** | Tool Schema Definitions | 1 | Execute | None | System Status tool, optimized descriptions, deployment guide |
| **03-03** | Confidence & Fallback Logic | 2 | Execute | 03-01 | Fallback handling, confidence scoring, SQL schema |
| **03-04** | Testing & Validation | 3 | Checkpoint | 03-01, 03-02, 03-03 | Test results, latency metrics, completion status |

---

## Documentation Structure

```
03-ai-routing-core/
├── README.md              — Phase overview, architecture, risks
├── QUICKSTART.md          — Execution guide with commands
├── INDEX.md               — This file (planning index)
│
├── 03-01-PLAN.md          — AI Agent routing configuration
├── 03-02-PLAN.md          — Tool schema definitions
├── 03-03-PLAN.md          — Confidence & fallback logic
├── 03-04-PLAN.md          — Testing & validation
│
└── (Generated during execution)
    ├── 03-01-TEST-CASES.md      — Routing accuracy tests (10 cases)
    ├── 03-02-DEPLOYMENT.md      — n8n deployment instructions
    ├── 03-03-TEST-CASES.md      — Fallback handling tests (16 cases)
    ├── 03-04-RESULTS.md         — Test execution results
    ├── 03-01-SUMMARY.md         — Plan 1 completion summary
    ├── 03-02-SUMMARY.md         — Plan 2 completion summary
    ├── 03-03-SUMMARY.md         — Plan 3 completion summary
    └── 03-04-SUMMARY.md         — Plan 4 completion summary
```

---

## Workflow Files Modified

| File | Plans | Changes |
|------|-------|---------|
| `workflow_supervisor_agent.json` | 03-01, 03-02, 03-03, 03-04 | Enhanced prompt, tool nodes, logging, metadata |
| `workflow_tool_system_status.json` | 03-02 | Structure validation only |
| `workflow_tool_create_task.json` | 03-02 | Structure validation only |
| `workflow_tool_security_scan.json` | 03-02 | Structure validation only |

### New Files Created
| File | Plan | Purpose |
|------|------|---------|
| `sql/routing_metrics.sql` | 03-03 | Analytics schema (optional) |

---

## Task Breakdown

### 03-01 (4 tasks, all auto)
1. Enhance AI Agent system prompt for routing
2. Verify and document tool connections
3. Add routing decision logging node
4. Create test case documentation

### 03-02 (4 tasks, all auto)
1. Create System Status tool node
2. Optimize existing tool descriptions
3. Validate tool workflow structures
4. Create deployment guide

### 03-03 (4 tasks, all auto)
1. Add confidence threshold and fallback logic
2. Enhance routing decision logging
3. Create PostgreSQL routing metrics table
4. Create fallback test cases

### 03-04 (5 tasks, 2 manual, 3 auto)
1. **[MANUAL]** Deploy workflows to production
2. **[MANUAL]** Execute routing accuracy test suite
3. **[MANUAL]** Measure routing latency
4. Validate success criteria
5. Update workflow metadata

**Total Tasks:** 17 (14 automated, 3 manual)

---

## Success Criteria Mapping

| Criteria | Primary Plan | Validation Plan |
|----------|--------------|-----------------|
| SC-3.1: Natural language health routing | 03-01, 03-02 | 03-04 |
| SC-3.2: ADHD Commander routing | 03-01, 03-02 | 03-04 |
| SC-3.3: Graceful degradation | 03-03 | 03-04 |
| SC-3.4: Routing decision logging | 03-01, 03-03 | 03-04 |
| SC-3.5: Latency <3 seconds | All | 03-04 |

---

## Execution Waves

### Wave 1 (Parallel)
- **03-01-PLAN.md** — Configure AI Agent
- **03-02-PLAN.md** — Define tool schemas
- **Can run simultaneously:** No conflicts between these plans

### Wave 2 (Sequential)
- **03-03-PLAN.md** — Implement fallback handling
- **Depends on:** 03-01 (requires enhanced prompt to exist)
- **Can start after:** 03-01 completes

### Wave 3 (Checkpoint)
- **03-04-PLAN.md** — Integration testing
- **Depends on:** 03-01, 03-02, 03-03 (all must be complete)
- **Requires:** Manual testing with Telegram

---

## Key Concepts

### AI Routing
- Uses Ollama qwen2.5:7b for intent classification
- Natural language understanding (not keyword matching)
- Tool selection based on user intent patterns

### Tool Schemas
- Each tool has descriptive name and usage examples
- AI Agent learns WHEN to call each tool from descriptions
- Connected via `@n8n/n8n-nodes-langchain.toolWorkflow` nodes

### Confidence Thresholds
- **HIGH (>80%):** Execute tool immediately
- **MEDIUM (50-80%):** Ask clarifying question
- **LOW (<50%):** Provide capability list

### Fallback Handling
- Gibberish → Helpful guidance (not error)
- Ambiguous → Clarification question
- Social → Friendly acknowledgment
- Always show what the system CAN do

---

## Testing Strategy

### Routing Accuracy (10 test cases)
- System health queries → System_Status tool
- Task queries → ADHD_Commander tool
- Finance queries → Finance_Manager tool
- General conversation → Direct response

### Fallback Handling (16 test cases)
- Gibberish (4 tests) → No errors, helpful responses
- Ambiguous (4 tests) → Clarification questions
- Social (4 tests) → Friendly acknowledgments
- Edge cases (4 tests) → Graceful handling

### Performance (SC-3.5)
- Measure latency across 10+ samples
- Target: <3000ms average
- Log via ROUTING_DECISION entries

**Pass Threshold:** 18/20 routing + 14/16 fallback = 32/36 total (89%)

---

## Critical Path

```
03-01 ──┐
        ├──> 03-03 ──┐
03-02 ──┘            ├──> 03-04 (checkpoint)
                     │
                     └──> Phase 3 Complete
```

**Estimated Timeline:**
- Wave 1: 2 hours (parallel execution)
- Wave 2: 1.5 hours (sequential)
- Wave 3: 2-3 hours (manual testing)
- **Total:** 5.5-6.5 hours

---

## Risk Mitigation

| Risk | Mitigation | Owner Plan |
|------|------------|------------|
| Tool workflow ID mismatch | Manual verification in deployment | 03-04 |
| Ollama cold start latency | KEEP_ALIVE=24h (Phase 1) | 03-04 |
| Over-routing simple queries | Temperature=0.4, clear examples | 03-01 |
| Fallback too aggressive | Test and tune threshold | 03-03, 03-04 |

---

## Exit Criteria (Phase 3 Complete)

- [ ] All 4 plans executed
- [ ] All 4 SUMMARY files created
- [ ] 4/5 success criteria passed (minimum)
- [ ] Test results documented
- [ ] Workflow metadata updated to v3.0.0
- [ ] ROADMAP.md updated with plan references ✅
- [ ] Ready for Phase 4: Memory & Context

---

## Quick Links

- [Phase Overview](README.md)
- [Execution Guide](QUICKSTART.md)
- [Main Roadmap](../../ROADMAP.md)
- [Project Context](../../PROJECT.md)

---

*Planning index for Phase 3: AI Routing Core | Last updated: 2026-02-04*
