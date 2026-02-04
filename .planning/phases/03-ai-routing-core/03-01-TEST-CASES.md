# Phase 03-01 Routing Test Cases

**Created:** 2026-02-04
**Purpose:** Validate AI Agent routing accuracy with natural language understanding
**Success Criteria:** SC-3.1, SC-3.2, SC-3.3, SC-3.4

---

## Success Criteria Coverage

### SC-3.1: System health routing (natural language)

**TC-1: Direct system check**
- **Input:** "Check system health"
- **Expected:** System_Status tool called
- **Rationale:** Direct keyword match for health check

**TC-2: Conversational health query**
- **Input:** "Is the server okay?"
- **Expected:** System_Status tool called
- **Rationale:** Natural language variation, no exact keywords

**TC-3: Infrastructure status query**
- **Input:** "How's EC2 doing?"
- **Expected:** System_Status tool called
- **Rationale:** Specific infrastructure component mentioned

---

### SC-3.2: ADHD Commander routing

**TC-4: Task selection request**
- **Input:** "What's on my plate today?"
- **Expected:** ADHD_Commander tool called
- **Rationale:** Natural language for task query

**TC-5: Direct focus request**
- **Input:** "Give me a focus task"
- **Expected:** ADHD_Commander tool called
- **Rationale:** Explicit task request with keyword "focus"

**TC-6: Analysis paralysis expression**
- **Input:** "I don't know what to work on"
- **Expected:** ADHD_Commander tool called
- **Rationale:** Intent-based routing for decision paralysis

---

### SC-3.3: Graceful degradation (fallback handling)

**TC-7: Gibberish input**
- **Input:** "asdfghjkl"
- **Expected:** Clarification or "I didn't understand" response (NO tool call)
- **Rationale:** Nonsensical input should not trigger tools

**TC-8: Random word salad**
- **Input:** "banana robot 42"
- **Expected:** Helpful clarification response (NO tool call)
- **Rationale:** Unclear intent should prompt for clarification

---

### SC-3.4: General conversation (no tool routing)

**TC-9: Simple greeting**
- **Input:** "Hello"
- **Expected:** Direct friendly response (NO tool call)
- **Rationale:** Social greeting doesn't require tool execution

**TC-10: Appreciation message**
- **Input:** "Thanks for the help"
- **Expected:** Direct acknowledgment (NO tool call)
- **Rationale:** Simple acknowledgment, no action required

---

## Finance Manager Routing (Bonus Coverage)

**TC-11: Transaction logging**
- **Input:** "I paid $150 for AWS today"
- **Expected:** Finance_Manager tool called
- **Rationale:** Financial transaction with amount and category

**TC-12: Debt status query**
- **Input:** "What's my debt status?"
- **Expected:** Finance_Manager tool called
- **Rationale:** Financial information request

---

## Expected Logging Output

Each test should produce a console log entry in n8n execution logs:

```json
{
  "event": "routing_decision",
  "timestamp": "2026-02-04T...",
  "executionId": "...",
  "tools_called": [],
  "confidence_estimate": "HIGH|MEDIUM|LOW",
  "response_length": 150,
  "has_tool_output": false
}
```

### Logging Validation Criteria

- **TC-1 to TC-6, TC-11, TC-12:** `tools_called` array should contain tool name
- **TC-1 to TC-6, TC-11, TC-12:** `has_tool_output: true`
- **TC-1 to TC-6, TC-11, TC-12:** `confidence_estimate: "HIGH"`
- **TC-7 to TC-10:** `tools_called: []` (empty array)
- **TC-7 to TC-10:** `has_tool_output: false`
- **All TCs:** `event: "routing_decision"` present
- **All TCs:** `executionId` matches n8n execution ID

---

## Manual Testing Procedure

### Prerequisites
1. Supervisor Agent workflow deployed to n8n
2. Telegram bot accessible via `@Coredirective_bot`
3. All tool workflows deployed and active
4. PostgreSQL database available for deduplication

### Execution Steps
1. Open Telegram and start conversation with `@Coredirective_bot`
2. Send each test message one at a time
3. Wait for response (should be <3 seconds per SC-3.5)
4. Check n8n execution logs for `ROUTING_DECISION:` entries
5. Record actual behavior vs expected behavior
6. Note any anomalies or unexpected tool calls

### Logging Access
```bash
# SSH to EC2 instance
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244

# View n8n container logs
docker logs n8n -f --tail=100 | grep "ROUTING_DECISION"

# Or view via n8n UI
# Navigate to: Executions > Latest > View Logs
```

---

## Pass Criteria

**Routing Accuracy:**
- **8/10 core test cases** route correctly (TC-1 through TC-10)
- **All routing decisions logged** with correct structure
- **No system errors or timeouts**

**Latency (SC-3.5):**
- Average response time <3000ms across all test cases
- Measured from Telegram message send to response received
- Logged in `SUPERVISOR_AGENT_OUTGOING` entries as `latencyMs`

**Fallback Behavior:**
- TC-7, TC-8: Must NOT call any tools
- TC-7, TC-8: Must provide helpful guidance, not error messages
- TC-9, TC-10: Must respond conversationally without tools

---

## Results Template

Use this template to record test results (will be created in 03-04-PLAN.md):

```markdown
## Test Execution Results

**Date:** YYYY-MM-DD
**Tester:** [Name]
**Environment:** Production EC2 instance

| TC | Input | Expected Tool | Actual Tool | Pass/Fail | Latency (ms) | Notes |
|----|-------|---------------|-------------|-----------|--------------|-------|
| TC-1 | "Check system health" | System_Status | ... | ... | ... | ... |
| TC-2 | "Is the server okay?" | System_Status | ... | ... | ... | ... |
| ... | ... | ... | ... | ... | ... | ... |

**Overall Pass Rate:** X/10 (X%)
**Average Latency:** XXXms
**Success Criteria Met:** YES/NO
```

---

## Known Limitations

1. **Tool Workflow IDs:** System_Status tool currently has placeholder ID `SYSTEM_STATUS_WORKFLOW_ID` - must be updated in 03-02-PLAN.md before testing
2. **Ollama Cold Start:** First query after inactivity may exceed 3s latency (KEEP_ALIVE=24h mitigates this)
3. **Context Dependency:** Some queries may be interpreted differently based on chat history (13-message memory window)
4. **Ambiguity Zone:** Queries in the 50-70% confidence range may behave inconsistently

---

## Future Enhancements (Post-Phase 03)

- Add routing confidence scores to logs (currently proxy via tool usage)
- Track routing accuracy metrics over time in PostgreSQL
- A/B test different system prompts for routing optimization
- Implement explicit confidence scoring in AI Agent response

---

**Reference:**
- [03-01-PLAN.md](03-01-PLAN.md) - Original plan specification
- [QUICKSTART.md](QUICKSTART.md) - Phase 3 execution guide
- [03-04-PLAN.md](03-04-PLAN.md) - Testing and validation plan

---

*Test cases for Phase 03-01: AI Agent Routing Configuration*
