# Phase 3: AI Routing Core

**Status:** Ready for execution
**Created:** 2026-02-04
**Dependencies:** Phase 2 (Webhook & Message Intake)

---

## Overview

This phase implements intelligent message routing using Ollama qwen2.5:7b, enabling natural language understanding instead of rigid keyword matching. The AI Agent will route incoming Telegram messages to appropriate tool workflows based on user intent.

## Success Criteria

- **SC-3.1**: "Check system health" routes to status tool (not keyword-matched)
- **SC-3.2**: "What's on my plate today" routes to ADHD Commander
- **SC-3.3**: Gibberish input returns "I didn't understand" (graceful degradation)
- **SC-3.4**: Routing decision logged with confidence score
- **SC-3.5**: Average routing latency <3 seconds

## Requirements

- **ROUTE-02**: AI agent (Ollama qwen2.5:7b) routes messages to appropriate sub-workflow
- **ROUTE-03**: Natural language understanding (no strict command syntax required)

## Plans

### Wave 1 (Parallel Execution)
- **03-01-PLAN.md** — Configure LangChain AI Agent with routing prompt
  - Enhance system prompt with routing logic and examples
  - Add routing decision logging
  - Create test case documentation
  - Status: Ready

- **03-02-PLAN.md** — Define tool schemas for sub-workflows
  - Create System Status tool node
  - Optimize ADHD Commander and Finance Manager descriptions
  - Validate all tool workflows
  - Create deployment guide
  - Status: Ready

### Wave 2 (Sequential)
- **03-03-PLAN.md** — Implement confidence threshold and fallback handling
  - Add fallback logic to AI Agent prompt
  - Enhance confidence estimation in logging
  - Create routing metrics SQL schema (optional)
  - Create fallback test cases
  - Status: Ready
  - Depends on: 03-01

### Wave 3 (Checkpoint)
- **03-04-PLAN.md** — Integration testing and latency validation
  - Deploy workflows to production
  - Execute 26 test cases (routing + fallback)
  - Measure routing latency
  - Validate all success criteria
  - Update workflow metadata
  - Status: Ready
  - Depends on: 03-01, 03-02, 03-03
  - **Type:** Manual testing required

## Key Files

### Modified
- `COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json` - Main routing workflow
- `COREDIRECTIVE_ENGINE/workflow_tool_system_status.json` - System health tool
- `COREDIRECTIVE_ENGINE/workflow_tool_create_task.json` - Task creation (validated only)
- `COREDIRECTIVE_ENGINE/workflow_tool_security_scan.json` - Security scan (validated only)

### Created
- `.planning/phases/03-ai-routing-core/03-01-TEST-CASES.md` - Routing accuracy tests
- `.planning/phases/03-ai-routing-core/03-03-TEST-CASES.md` - Fallback handling tests
- `.planning/phases/03-ai-routing-core/03-02-DEPLOYMENT.md` - Deployment instructions
- `.planning/phases/03-ai-routing-core/03-04-RESULTS.md` - Test results (post-execution)
- `COREDIRECTIVE_ENGINE/sql/routing_metrics.sql` - Analytics schema (optional)

## Architecture Changes

### Before Phase 3
```
Telegram → Parse Input → AI Agent → Format Output → Send Response
                            ↓
                    (Direct responses only)
```

### After Phase 3
```
Telegram → Parse Input → AI Agent → Log Routing → Format Output → Send Response
                            ↓           ↓
                        Tools      Confidence
                          ↓         Logging
                   ┌──────┼──────┐
                   ↓      ↓      ↓
              System  ADHD    Finance
              Status  Cmd     Manager
```

## Testing Strategy

### Routing Accuracy (10 test cases)
- System health queries → System_Status
- Task selection queries → ADHD_Commander
- Finance queries → Finance_Manager
- General conversation → Direct response

### Fallback Handling (16 test cases)
- Gibberish inputs → Helpful guidance
- Ambiguous inputs → Clarification questions
- Social inputs → Friendly responses
- Edge cases → No errors

### Performance
- Measure latency across 10+ samples
- Target: <3 seconds average
- Monitor via ROUTING_DECISION logs

## Exit Criteria

- [ ] 18/20 routing test cases pass
- [ ] 14/16 fallback test cases pass
- [ ] Confidence scores logged for all routing decisions
- [ ] Average latency <3 seconds
- [ ] All 5 success criteria validated

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Ollama timeout on first call | High latency | Phase 1 KEEP_ALIVE=24h prevents cold starts |
| Tool workflow ID mismatch | Routing failure | Manual verification in 03-04 deployment |
| Over-routing to tools | Poor UX for simple queries | Temperature=0.4, clear system prompt |
| Under-confidence on valid inputs | Too many clarifications | Test and tune prompt in 03-04 |

## Notes

- **Manual intervention required:** 03-04-PLAN.md requires human testing via Telegram
- **Optional enhancements:** routing_metrics.sql table can be added later for analytics
- **Tool workflows:** Create Task and Security Scan validated but not connected (Phase 9/10)
- **Existing tools:** ADHD Commander and Finance Manager already connected (verify IDs)

## Next Phase

**Phase 4: Memory & Context** will build on this routing core by adding conversation memory to enable multi-turn context ("Add that task" referencing previous message).

---

*Last updated: 2026-02-04*
