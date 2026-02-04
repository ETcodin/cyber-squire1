# Test Cases: Confidence Threshold & Fallback Handling

**Phase:** 03 - AI Routing Core
**Plan:** 03-03 - Implement Confidence Threshold and Fallback Handling
**Created:** 2026-02-04
**Success Criteria:** SC-3.3 (Gibberish returns helpful guidance), SC-3.4 (Confidence scores logged with multiple signals)

---

## Overview

This document defines comprehensive test cases for validating the confidence threshold system and fallback handling mechanisms implemented in the Supervisor Agent. The system uses multi-signal confidence estimation to gracefully handle unclear, ambiguous, or nonsensical inputs.

## Test Categories

1. **HIGH Confidence (≥70%)** - Clear tool mapping
2. **MEDIUM Confidence (40-69%)** - Ambiguous/partial match
3. **LOW Confidence (<40%)** - Gibberish/unclear
4. **Fallback Triggers** - Specific edge cases
5. **Confidence Signal Validation** - Multi-signal scoring
6. **Analytics & Logging** - PostgreSQL metrics

---

## TC-01: HIGH Confidence Scenarios (≥70%)

### TC-01.1: System Status - Direct Request
**Input:** "Check system health"
**Expected Behavior:**
- Tool Called: `System_Status`
- Confidence Level: `HIGH`
- Confidence Score: ≥70
- Response: Direct status report, no clarification needed
- Signals:
  - `signal_tool`: 100 (tool invoked)
  - `signal_keywords`: ≥50 ("system", "health")
  - `signal_length`: 70 (19 chars)
  - `signal_specificity`: 80 (specific response)

**Validation:**
```sql
SELECT confidence_level, confidence_score, tools_called, signal_tool, signal_keywords
FROM routing_decisions
WHERE execution_id = 'TC-01.1'
  AND confidence_level = 'HIGH'
  AND 'System_Status' = ANY(tools_called);
```

---

### TC-01.2: ADHD Commander - Clear Priority Request
**Input:** "What should I work on right now?"
**Expected Behavior:**
- Tool Called: `ADHD_Commander`
- Confidence Level: `HIGH`
- Confidence Score: ≥80
- Response: Task from Notion with reasoning
- Keywords Found: `['what', 'work']`

**Validation:**
- Check `routing_decisions.keywords_found` contains "what" and "work"
- Verify `tool_routing_accuracy` increments for `ADHD_Commander`

---

### TC-01.3: Finance Manager - Explicit Transaction
**Input:** "I paid $150 for groceries today"
**Expected Behavior:**
- Tool Called: `Finance_Manager`
- Confidence Level: `HIGH`
- Confidence Score: ≥85
- Response: Transaction logged confirmation
- Keywords Found: `['paid', 'money']`

---

### TC-01.4: Multiple Keywords - Compound Query
**Input:** "Can you check if the server is running and also give me today's focus task?"
**Expected Behavior:**
- Tools Called: `System_Status`, `ADHD_Commander` (multi-tool)
- Confidence Level: `HIGH`
- Confidence Score: ≥75
- Response: Combined output from both tools
- Keywords Found: `['server', 'task', 'focus']`

**Note:** Validates that compound queries maintain high confidence when intent is clear.

---

## TC-02: MEDIUM Confidence Scenarios (40-69%)

### TC-02.1: Ambiguous - "Things broken?"
**Input:** "Things broken?"
**Expected Behavior:**
- Tool Called: Possibly `System_Status` OR clarification question
- Confidence Level: `MEDIUM`
- Confidence Score: 40-69
- Response: "Do you want me to check system health, or is this about a specific task?"
- Fallback Triggers: `['no_keywords']` or none

**Validation:**
- If confidence 40-69 with `is_fallback_response = FALSE`, should ask clarification
- Check `signal_keywords` is low (<50) due to generic "things"

---

### TC-02.2: Partial Match - "Money stuff"
**Input:** "Money stuff"
**Expected Behavior:**
- Tool Called: `Finance_Manager` (likely) OR clarification
- Confidence Level: `MEDIUM`
- Confidence Score: 50-69
- Keywords Found: `['money']`
- Response: Either direct Finance_Manager call or "Did you want to log a transaction, or check your financial status?"

**Validation:**
```sql
SELECT confidence_level, tools_called, keywords_found
FROM routing_decisions
WHERE input_text = 'Money stuff'
  AND confidence_level = 'MEDIUM';
```

---

### TC-02.3: Typo - "Waht shud I fokus on?"
**Input:** "Waht shud I fokus on?"
**Expected Behavior:**
- Tool Called: `ADHD_Commander` (fuzzy matching should still work)
- Confidence Level: `MEDIUM` (downgraded due to typos)
- Confidence Score: 50-65
- Keywords Found: Possibly `['focus']` if model handles typos
- Response: Direct task or clarification

**Note:** Tests robustness to user input errors.

---

### TC-02.4: Contextual Follow-up - "And after that?"
**Input:** "And after that?" (following a previous task assignment)
**Expected Behavior:**
- Tool Called: `ADHD_Commander` (context from chat memory)
- Confidence Level: `MEDIUM` (depends on chat history)
- Confidence Score: 45-60
- Response: Next task or clarification if context unclear

**Note:** Requires chat memory to be functional.

---

## TC-03: LOW Confidence Scenarios (<40%)

### TC-03.1: Gibberish - Random Characters
**Input:** "asdfqwerzxcv"
**Expected Behavior:**
- Tool Called: NONE
- Confidence Level: `LOW`
- Confidence Score: <40
- Response: "I can help you with: tasks (ADHD Commander), money tracking (Finance Manager), or system health (System Status). What would be most useful right now?"
- Fallback Triggers: `['random_characters', 'no_keywords']`
- `is_fallback_response`: `TRUE`

**Validation:**
```sql
SELECT confidence_level, is_fallback_response, fallback_triggers
FROM routing_decisions
WHERE input_text = 'asdfqwerzxcv'
  AND confidence_level = 'LOW'
  AND is_fallback_response = TRUE
  AND 'random_characters' = ANY(fallback_triggers);
```

**Success Criteria SC-3.3:** ✅ Gibberish returns helpful guidance, not errors.

---

### TC-03.2: Emoji-Only Message
**Input:** "🤔🤷‍♂️😵"
**Expected Behavior:**
- Tool Called: NONE
- Confidence Level: `LOW`
- Confidence Score: <30
- Response: Helpful orientation (same as TC-03.1)
- Fallback Triggers: `['emoji_only']`
- `is_fallback_response`: `TRUE`

**Note:** Should not attempt to interpret emojis as commands.

---

### TC-03.3: Too Short - "a"
**Input:** "a"
**Expected Behavior:**
- Tool Called: NONE
- Confidence Level: `LOW`
- Confidence Score: <20
- Response: Fallback orientation message
- Fallback Triggers: `['too_short']`
- `is_fallback_response`: `TRUE`

---

### TC-03.4: Nonsensical Sentence
**Input:** "The purple elephant dances with quantum socks"
**Expected Behavior:**
- Tool Called: NONE
- Confidence Level: `LOW`
- Confidence Score: <35
- Response: Fallback orientation (no apologizing, just helpful)
- Fallback Triggers: `['no_keywords']`
- `is_fallback_response`: `TRUE`

**Validation:** Response should NOT contain phrases like:
- "I'm confused"
- "I don't understand"
- "I don't have that capability"

---

### TC-03.5: Non-English (Potential Future Enhancement)
**Input:** "¿Cómo está el sistema?"
**Expected Behavior:**
- Tool Called: NONE (current version English-only)
- Confidence Level: `LOW`
- Confidence Score: <40
- Response: Fallback orientation
- Fallback Triggers: `['no_keywords']` (unless "sistema" matches)

**Note:** Future enhancement could detect language and respond accordingly.

---

## TC-04: Fallback Trigger Edge Cases

### TC-04.1: Greeting - "hi" (Exception to too_short)
**Input:** "hi"
**Expected Behavior:**
- Tool Called: NONE
- Confidence Level: `MEDIUM` or `HIGH` (greeting is valid)
- Confidence Score: 60-80
- Response: Friendly direct response (not fallback)
- Fallback Triggers: NONE or `[]`
- `is_fallback_response`: `FALSE`

**Validation:** Short greetings should bypass too_short trigger.

---

### TC-04.2: Number-Only Input - "12345"
**Input:** "12345"
**Expected Behavior:**
- Tool Called: NONE (unless interpreting as amount?)
- Confidence Level: `LOW`
- Confidence Score: <30
- Response: Fallback orientation
- Fallback Triggers: `['no_keywords']`

---

### TC-04.3: Special Characters - "!@#$%^&*()"
**Input:** "!@#$%^&*()"
**Expected Behavior:**
- Tool Called: NONE
- Confidence Level: `LOW`
- Confidence Score: <20
- Response: Fallback orientation
- Fallback Triggers: `['emoji_only']` (same logic for special chars)

---

### TC-04.4: Mixed Case Gibberish - "AsDF QwEr ZxCv"
**Input:** "AsDF QwEr ZxCv"
**Expected Behavior:**
- Tool Called: NONE
- Confidence Level: `LOW`
- Confidence Score: <35
- Response: Fallback orientation
- Fallback Triggers: `['random_characters', 'no_keywords']`

**Validation:** Case-insensitive matching should still detect gibberish.

---

## TC-05: Confidence Signal Validation

### TC-05.1: Tool Signal Dominance
**Scenario:** Direct tool call with clear intent
**Input:** "Check system status"
**Expected Signals:**
- `signal_tool`: 100 (tool invoked)
- `signal_keywords`: 75 (both keywords match)
- `signal_length`: 70 (18 chars)
- `signal_specificity`: 80 (specific response)
- **Weighted Score:** ~85 (HIGH)

**Calculation Validation:**
```
(100 * 0.4) + (75 * 0.25) + (70 * 0.15) + (80 * 0.2) =
40 + 18.75 + 10.5 + 16 = 85.25 ≈ 85
```

---

### TC-05.2: Keyword Signal Impact
**Scenario:** Multiple keywords but ambiguous intent
**Input:** "Help with task and money and server stuff"
**Expected Signals:**
- `signal_keywords`: 75-100 (many keywords)
- `signal_tool`: Variable (may call tool or ask clarification)
- `signal_length`: 70 (good length)
- **Weighted Score:** ~60-75 (MEDIUM or HIGH)

**Note:** Too many keywords may reduce specificity.

---

### TC-05.3: Length Signal Edge Case
**Scenario:** Very short valid command
**Input:** "task"
**Expected Signals:**
- `signal_length`: 40 (4 chars, short but >2)
- `signal_keywords`: 25 (one keyword)
- `signal_tool`: 100 or 0 (may invoke ADHD_Commander)
- **Weighted Score:** Variable based on tool invocation

---

### TC-05.4: Specificity Signal - Fallback Detection
**Scenario:** Input triggers fallback response
**Input:** "xyzabc"
**Expected Signals:**
- `signal_specificity`: 20 (fallback response detected)
- `signal_keywords`: 0 (no matches)
- `signal_length`: 40 (6 chars)
- `signal_tool`: 30 (no tool, short response)
- **Weighted Score:** ~25 (LOW)

**Calculation Validation:**
```
(30 * 0.4) + (0 * 0.25) + (40 * 0.15) + (20 * 0.2) =
12 + 0 + 6 + 4 = 22 ≈ 25 (LOW)
```

**Success Criteria SC-3.4:** ✅ Confidence scores logged with multiple signals.

---

## TC-06: Analytics & Logging Validation

### TC-06.1: Routing Decision Logged
**Test:** Every execution creates routing_decisions record
**Validation Query:**
```sql
SELECT COUNT(*) FROM routing_decisions
WHERE execution_id IN ('TC-01.1', 'TC-02.1', 'TC-03.1');
-- Should return 3
```

---

### TC-06.2: Fallback Pattern Aggregation
**Test:** Multiple identical gibberish inputs aggregate correctly
**Steps:**
1. Send "qwerty" 5 times
2. Check fallback_patterns table

**Validation:**
```sql
SELECT pattern_hash, occurrence_count, trigger_type
FROM fallback_patterns
WHERE input_pattern = 'qwerty';
-- Should show occurrence_count = 5, trigger_type = 'random_characters'
```

---

### TC-06.3: Tool Accuracy Daily Stats
**Test:** Tool calls increment daily accuracy metrics
**Validation:**
```sql
SELECT tool_name, total_calls, high_confidence_calls, avg_confidence
FROM tool_routing_accuracy
WHERE date = CURRENT_DATE
  AND tool_name = 'ADHD_Commander';
-- Should increment after TC-01.2
```

---

### TC-06.4: View: Daily Routing Summary
**Test:** Aggregate view calculates correctly
**Validation:**
```sql
SELECT * FROM v_daily_routing_summary
WHERE date = CURRENT_DATE;
-- Should show totals for all test cases run today
```

---

### TC-06.5: View: Tool Usage with Confidence
**Test:** Per-tool confidence breakdown
**Validation:**
```sql
SELECT * FROM v_tool_usage_with_confidence
WHERE tool_name = 'System_Status';
-- Should show avg_confidence and call breakdown by confidence level
```

---

### TC-06.6: Console Log Format
**Test:** Structured logging to n8n console
**Expected Log Entry (JSON):**
```json
{
  "event": "routing_decision",
  "timestamp": "2026-02-04T18:00:00.000Z",
  "executionId": "test-exec-123",
  "chat_id": "123456789",
  "user": "testuser",
  "tools_called": ["System_Status"],
  "tool_count": 1,
  "confidence_score": 85,
  "confidence_level": "HIGH",
  "signal_tool": 100,
  "signal_keywords": 75,
  "signal_length": 70,
  "signal_specificity": 80,
  "input_length": 18,
  "keywords_found": ["system", "status"],
  "fallback_triggers": [],
  "is_fallback_response": false,
  "response_length": 256,
  "sql_ready": true
}
```

**Validation:** Check n8n execution logs for `ROUTING_DECISION:` prefix.

---

## TC-07: Integration Test Scenarios

### TC-07.1: Conversation Flow - Fallback to Clarification to Success
**Steps:**
1. User: "zzzz" → LOW confidence fallback
2. User: "tasks" → MEDIUM/HIGH confidence ADHD_Commander
3. Validate chat memory persists context

**Expected:**
- Step 1: Fallback response with options
- Step 2: Direct tool call or task selection
- Step 3: Second message references first (chat memory)

---

### TC-07.2: Rapid-Fire Same Query
**Steps:**
1. Send "check system" 3 times in quick succession
2. Validate deduplication works (message_log)
3. Check routing_decisions only has 1 entry per unique message_id

---

### TC-07.3: Cross-Tool Handoff
**Steps:**
1. User: "What's the priority task?" → ADHD_Commander
2. User: "Log time spent on it" → Finance_Manager (future time tracking)
3. Validate both tools called in sequence

**Note:** Requires Finance_Manager to support time tracking (future).

---

## TC-08: Performance & Limits

### TC-08.1: Very Long Input
**Input:** 4000 character message (near Telegram limit)
**Expected Behavior:**
- Confidence scoring still works
- Response truncated to 4000 chars (handled in Format Output node)
- No execution timeout

---

### TC-08.2: Concurrent Executions
**Test:** 10 simultaneous messages from different users
**Expected Behavior:**
- All routing decisions logged independently
- No race conditions in PostgreSQL inserts
- Average latency <2000ms

---

### TC-08.3: Latency Under Load
**Test:** Single user sends 50 messages in 1 minute
**Expected Behavior:**
- Deduplication prevents duplicate processing
- Average confidence scoring latency <500ms
- PostgreSQL handles insert volume (50/min = 3000/hour)

---

## Success Criteria Validation

### ✅ SC-3.3: Gibberish returns helpful guidance, not errors
**Validated By:**
- TC-03.1 (random characters)
- TC-03.2 (emoji-only)
- TC-03.3 (too short)
- TC-03.4 (nonsensical sentence)

**Pass Conditions:**
- No error responses
- Fallback messages are friendly and helpful
- No "I don't understand" or "I'm confused" phrases
- Response includes tool options
- Response is <100 words (ADHD-friendly)

---

### ✅ SC-3.4: Confidence scores logged with multiple signals
**Validated By:**
- TC-05.1 through TC-05.4 (signal calculations)
- TC-06.1 through TC-06.6 (logging validation)

**Pass Conditions:**
- All 4 signals logged: `signal_tool`, `signal_keywords`, `signal_length`, `signal_specificity`
- Weighted average calculation matches expected formula
- Confidence level (HIGH/MEDIUM/LOW) matches score ranges
- PostgreSQL `routing_decisions` table populated
- Console logs include structured JSON with all signals

---

## Test Execution Checklist

- [ ] Deploy updated `workflow_supervisor_agent.json` to n8n
- [ ] Run `routing_metrics.sql` to create tables/views
- [ ] Execute TC-01 (HIGH confidence) - verify tool calls
- [ ] Execute TC-02 (MEDIUM confidence) - verify clarifications
- [ ] Execute TC-03 (LOW confidence) - verify fallback messages (SC-3.3)
- [ ] Execute TC-05 (signal validation) - verify calculations (SC-3.4)
- [ ] Execute TC-06 (logging) - verify PostgreSQL inserts
- [ ] Run analytics queries - verify views return data
- [ ] Check n8n console logs for `ROUTING_DECISION:` entries
- [ ] Validate no error/warning messages in execution logs
- [ ] Document any deviations in SUMMARY.md

---

## Future Enhancements (Out of Scope for 03-03)

1. **User Feedback Loop:** `/feedback good` or `/feedback bad` commands to track routing accuracy
2. **A/B Testing:** Compare confidence threshold values (70% vs 60% vs 80%)
3. **Multi-language Support:** Detect non-English and provide localized fallbacks
4. **Context-Aware Scoring:** Use chat history to boost confidence
5. **Fallback Pattern Learning:** Automatically suggest new tool keywords based on fallback patterns

---

## Appendix: SQL Test Data Setup

```sql
-- Insert sample test data for validation
INSERT INTO routing_decisions (
    execution_id, chat_id, user_id, input_text, input_length,
    keywords_found, tools_called, tool_count, confidence_score, confidence_level,
    signal_tool, signal_keywords, signal_length, signal_specificity,
    response_length, is_fallback_response, fallback_triggers
) VALUES
    ('TC-01.1', '123456789', 'testuser', 'Check system health', 19,
     ARRAY['system', 'health'], ARRAY['System_Status'], 1, 85, 'HIGH',
     100, 50, 70, 80, 256, FALSE, ARRAY[]::TEXT[]),
    ('TC-03.1', '123456789', 'testuser', 'asdfqwerzxcv', 12,
     ARRAY[]::TEXT[], ARRAY[]::TEXT[], 0, 22, 'LOW',
     30, 0, 40, 20, 98, TRUE, ARRAY['random_characters', 'no_keywords']);

-- Verify inserts
SELECT execution_id, confidence_level, is_fallback_response FROM routing_decisions
WHERE execution_id IN ('TC-01.1', 'TC-03.1');
```

---

**Document Version:** 1.0
**Last Updated:** 2026-02-04
**Next Review:** After Phase 03-04 deployment
