# Phase 4: Memory & Context - Usage Examples

This document provides real-world examples of how conversation context enables natural, multi-turn interactions with the Supervisor Agent.

## Example 1: Task Management Flow

### Without Context (Stateless)
```
User: I need to deploy the monitoring dashboard this week
Bot: I can help you with task management using ADHD Commander. What task would you like to add?

User: Add that task
Bot: I'm not sure which task you're referring to. Could you please specify the task you want to add?

User: The monitoring dashboard deployment
Bot: [Calls ADHD_Commander with "monitoring dashboard deployment"]
```
**Problem**: User had to repeat themselves, creating friction and cognitive load.

### With Context (Phase 4)
```
User: I need to deploy the monitoring dashboard this week
Bot: Got it. Would you like me to add "deploy the monitoring dashboard" to your Notion task board?

User: Add that task
Bot: [Calls ADHD_Commander with "deploy the monitoring dashboard"]
     ✓ Added task to your Notion board: "Deploy monitoring dashboard - Week Priority"

User: How long will it take?
Bot: Based on similar infrastructure tasks, deploying a monitoring dashboard typically takes 2-3 hours. This includes setup, configuration, and initial testing.

User: Schedule it for Thursday afternoon
Bot: I'll note that you're planning to work on "Deploy monitoring dashboard" on Thursday afternoon. Would you like me to create a calendar reminder?
```
**Benefits**:
- Natural conversation flow
- No repetition needed
- AI maintains task reference across 4 turns
- Reduced cognitive load (ADHD-friendly)

---

## Example 2: Financial Tracking

### Without Context
```
User: I just paid $150 for AWS this month
Bot: [No action - doesn't recognize financial intent clearly]

User: Log that expense
Bot: What expense would you like to log? Please provide the amount and category.

User: $150 for AWS
Bot: [Calls Finance_Manager with $150 and AWS category]
```

### With Context
```
User: I just paid $150 for AWS this month
Bot: I see you have an AWS expense. Would you like me to log $150 to your ledger?

User: Log it
Bot: [Calls Finance_Manager with amount=$150, category=Infrastructure, vendor=AWS]
     ✓ Logged expense: $150 AWS infrastructure (Month: February 2026)
     💡 Note: This is $30 higher than your January AWS bill. Monitor for cost creep.

User: What's my total infrastructure spend this month?
Bot: Let me check your expenses...
     [Retrieves from Finance_Manager]
     Total infrastructure spend (February): $285
     - AWS: $150
     - Cloudflare: $50
     - DigitalOcean: $85
```
**Benefits**:
- Contextual amount/vendor extraction
- Proactive cost monitoring
- Follow-up questions work naturally

---

## Example 3: System Troubleshooting

### Without Context
```
User: The EC2 instance seems slow today
Bot: I can help you check system status. What would you like me to monitor?

User: Check its health
Bot: Which system would you like me to check?

User: The EC2 instance
Bot: [Calls System_Status]
```

### With Context
```
User: The EC2 instance seems slow today
Bot: Let me check the system health for you.
     [Calls System_Status]

     System Status Report:
     - CPU: 78% (elevated - Qwen inference running)
     - Memory: 12.8GB / 16GB (80% usage)
     - Disk: 45% used
     - Services: All containers running

     ℹ️ High CPU is from Ollama. This is expected during AI inference.

User: Is that normal?
Bot: Yes, 78% CPU is normal when processing AI requests. The Qwen 2.5 7B model uses significant CPU during inference. If you're experiencing slowness, it's likely due to concurrent requests or a large context window.

User: How can I speed it up?
Bot: Based on the system status showing high CPU from AI inference, here are optimization options:
     1. **Reduce concurrent requests**: Limit to 1-2 simultaneous conversations
     2. **Decrease context window**: Currently 13 messages - could reduce to 8-10
     3. **Upgrade instance**: t3.xlarge → t3.2xlarge (8 vCPU instead of 4)
     4. **Optimize model**: Switch to Qwen 1.5B (faster, less accurate)

     Which would you prefer?

User: Let's try reducing the context window
Bot: To reduce the context window from 13 to 8 messages:
     1. Open n8n workflow: Telegram Supervisor Agent
     2. Edit "Chat Memory" node
     3. Change "Context Window Length" from 13 to 8
     4. Save and activate

     This will reduce memory load and inference time. Note: AI will remember less conversation history.
```
**Benefits**:
- AI maintains "the EC2 instance" reference across 4 turns
- Contextual troubleshooting recommendations
- Natural question flow without re-explaining

---

## Example 4: Multi-Domain Conversation

### Without Context
```
User: What should I focus on today?
Bot: [Calls ADHD_Commander]
     Top priority task: "Deploy Phase 4 memory implementation" (Due: Today)

User: How much time do I have?
Bot: I need more context. What are you asking about?

User: For the deployment task
Bot: [Has no reference to "deployment task"]
     Could you clarify which deployment?
```

### With Context
```
User: What should I focus on today?
Bot: [Calls ADHD_Commander]
     🎯 Focus Task: Deploy Phase 4 memory implementation
     - Estimated time: 2-3 hours
     - Priority: HIGH (Due: Today)
     - Status: In Progress

     Would you like me to break this down into subtasks?

User: How much time do I have?
Bot: Looking at your schedule, you have approximately 4 hours of focused work time remaining today:
     - 10:00-12:00 (2 hours - morning block)
     - 14:00-16:00 (2 hours - afternoon block)

     This is enough for "Deploy Phase 4" (2-3 hours). I recommend the morning block while energy is high.

User: I'm feeling low energy today
Bot: Understood. With sickle cell, low energy days require different prioritization. Given you're at low energy:

     **Modified Recommendation**:
     - Skip "Deploy Phase 4" (high cognitive load)
     - Focus on lighter tasks: documentation review, testing
     - Reserve deployment for tomorrow when energy returns

     Would you like me to suggest low-energy tasks from your board?

User: Yes, what are good low-energy options?
Bot: [Calls ADHD_Commander with filter=low_energy]
     Low-energy tasks for today:
     1. **Review PR #42** (20 min) - Code review, no creative thinking
     2. **Update CHANGELOG** (15 min) - Mechanical task
     3. **Run test suite** (10 min setup, 30 min automated)

     Total: ~1 hour of actual work. Plenty of rest time. Which appeals to you?
```
**Benefits**:
- AI tracks task across 5 message turns
- Contextual energy management (sickle cell awareness)
- Seamless domain switching (tasks → schedule → health → tasks)
- No need to repeat "Phase 4 deployment" reference

---

## Example 5: Correction and Refinement

### Without Context
```
User: Add a task to review the security audit
Bot: [Calls ADHD_Commander]
     ✓ Task added: "Review security audit"

User: Actually, make it urgent
Bot: Make what urgent?

User: The security audit review
Bot: [Creates new task instead of updating]
```

### With Context
```
User: Add a task to review the security audit
Bot: [Calls ADHD_Commander]
     ✓ Task added: "Review security audit" (Priority: Normal, Due: This week)

User: Actually, make it urgent
Bot: [Understands "it" refers to security audit task]
     [Calls ADHD_Commander to update priority]
     ✓ Updated task: "Review security audit" → Priority: URGENT (Due: Today)

User: And add a note that it's for the ISO 27001 compliance
Bot: [Calls ADHD_Commander to update notes]
     ✓ Added note to "Review security audit": "Required for ISO 27001 compliance"

     Task details:
     - Title: Review security audit
     - Priority: URGENT
     - Due: Today
     - Notes: Required for ISO 27001 compliance

User: Perfect, remind me in 30 minutes
Bot: I'll set a reminder for "Review security audit" in 30 minutes (at 10:45 AM). You'll receive a Telegram notification.
```
**Benefits**:
- Task refinement without re-creating
- "it" and "that" references resolve correctly
- Natural correction flow

---

## Example 6: Complex Multi-Step Planning

### Without Context
```
User: I need to prepare for the client demo next week
Bot: What would you like me to help you with?

User: Break it down into tasks
Bot: Break what down?

User: The demo preparation
Bot: [Has no context of "demo"]
```

### With Context
```
User: I need to prepare for the client demo next week
Bot: Client demo preparation - let me help you structure this. What's the demo about?

User: Showing the Cyber-Squire AI operations platform
Bot: Got it - demo for Cyber-Squire AI platform next week. Let me break this into tasks:

     **Demo Preparation Checklist**:
     1. Prepare demo environment (isolated EC2 instance)
     2. Create demo script with use cases
     3. Set up sample data (fake tasks, expenses)
     4. Test all three tools (ADHD Commander, Finance, System Status)
     5. Prepare slide deck with architecture
     6. Dry run with colleague

     Would you like me to add these to your Notion board?

User: Yes, and prioritize the demo environment setup
Bot: [Calls ADHD_Commander]
     ✓ Added 6 tasks under "Client Demo Preparation"
     ✓ Set "Prepare demo environment" as URGENT (Due: 2 days before demo)

     Next steps:
     1. Deploy isolated EC2 for demo (Est: 1 hour)
     2. Clone workflows without production credentials (Est: 30 min)

     Would you like me to check current AWS costs before spinning up a new instance?

User: Good idea, what's the AWS spend?
Bot: [Calls Finance_Manager]
     Current AWS spend (February): $150
     - EC2 t3.xlarge (production): $85/month
     - Data transfer: $30
     - S3 storage: $10
     - Other: $25

     **Demo instance estimate**: +$40 for 7 days (t3.medium)

     ℹ️ Reminder: Destroy demo instance after client meeting to avoid ongoing costs.

User: Add a reminder to destroy it
Bot: [Calls ADHD_Commander]
     ✓ Added task: "Destroy demo EC2 instance" (Due: Day after client demo)
     ✓ Set as auto-reminder with cost warning

     Your demo plan is set:
     - 6 preparation tasks
     - Cost-conscious infrastructure ($40 budget)
     - Auto-cleanup reminder

     Anything else for the demo?
```
**Benefits**:
- AI maintains "demo" context across 7 message turns
- Domain switching: tasks → costs → tasks
- Proactive cost management suggestion
- Complex multi-step planning without losing thread

---

## Technical Context Flow

### How Context Window Works

**13-Message Window Example**:
```
[Message 1]  User: I need to deploy monitoring
[Message 2]  Bot: I can help with that...
[Message 3]  User: Add that task
[Message 4]  Bot: Added "deploy monitoring"
[Message 5]  User: How long will it take?
[Message 6]  Bot: Approximately 2-3 hours
[Message 7]  User: I spent $150 on AWS
[Message 8]  Bot: Log that expense?
[Message 9]  User: Yes
[Message 10] Bot: Logged $150 AWS expense
[Message 11] User: Check system status
[Message 12] Bot: [System status report]
[Message 13] User: Is the monitoring task done?
                   ↑ AI can still reference "monitoring" from message 1
[Message 14] Bot: Not yet, you added it at 10:15 AM
[Message 15] User: What was my first question?
                   ↑ Message 1 is now pruned (outside 13-window)
```

### Context Pruning Behavior
- **Window size**: 13 messages (user + assistant combined)
- **Pruning**: Automatic after each new message
- **Storage**: PostgreSQL chat_memory table
- **Session**: Isolated per Telegram chat_id

### Example Context Query
When user sends message #14, the AI receives:
```sql
SELECT role, content FROM chat_memory
WHERE session_id = '12345'  -- Telegram chat_id
ORDER BY created_at ASC
LIMIT 13;
```

**Result (context injected into AI prompt)**:
```
[2] Bot: I can help with that...
[3] User: Add that task
[4] Bot: Added "deploy monitoring"
[5] User: How long will it take?
[6] Bot: Approximately 2-3 hours
[7] User: I spent $150 on AWS
[8] Bot: Log that expense?
[9] User: Yes
[10] Bot: Logged $150 AWS expense
[11] User: Check system status
[12] Bot: [System status report]
[13] User: Is the monitoring task done?
[14] User: What was my first question?  ← Current message
```

Notice: Message 1 is pruned (not in context). AI cannot answer "What was my first question?" accurately if it was 14+ messages ago.

---

## Edge Cases & Limitations

### Limitation 1: Context Window Boundary
```
User: [Sends 20 messages about Task A]
User: Tell me about Task A
Bot: I don't have context about Task A (messages pruned beyond window)
```
**Mitigation**: For long-running topics, periodically summarize or create a Notion note.

### Limitation 2: Cross-Session Context
```
User (Chat 1): Remember my AWS password is hunter2
User (Chat 2): What's my AWS password?
Bot: I don't have that information (different session_id)
```
**Mitigation**: Expected behavior - sessions are isolated for privacy.

### Limitation 3: Tool State vs. Chat Memory
```
User: Add task "Deploy Phase 4"
Bot: [Adds to Notion]
User: [Restarts n8n]
User: Is that task complete?
Bot: Which task? (context exists, but Notion state is separate)
```
**Mitigation**: AI can call ADHD_Commander to check Notion, not rely on memory.

### Limitation 4: Ambiguous References
```
User: I need to deploy the dashboard and update the docs
Bot: Got it, two tasks added.
User: How long will it take?
Bot: Which task - dashboard deployment or docs update?
```
**Mitigation**: AI should ask for clarification when "it" is ambiguous.

---

## Best Practices for Users

### 1. Use Explicit References for Clarity
**Good**:
```
User: I need to deploy monitoring (Task A) and update docs (Task B)
User: How long will Task A take?
```

**Avoid**:
```
User: I need to deploy monitoring and update docs
User: How long will it take?  ← Ambiguous
```

### 2. Summarize After Long Conversations
After 10+ messages on one topic:
```
User: To summarize: we're deploying Phase 4, it takes 3 hours, costs $40, due Thursday
```
This "re-anchors" the context and prevents key details from being pruned.

### 3. Reference Timestamps for Past Actions
**Good**:
```
User: What task did I add 30 minutes ago?
```

**Avoid**:
```
User: What was the first task I mentioned?  ← May be outside window
```

### 4. Use Notion/Finance Tools as Source of Truth
Memory is for **conversation context**, not **persistent storage**.

**Good**:
```
User: What tasks are on my board?
Bot: [Calls ADHD_Commander to query Notion]
```

**Avoid**:
```
User: What tasks did we talk about yesterday?  ← Outside 13-window
```

---

## Success Metrics

### Quantitative
- **Context Hit Rate**: % of references ("that task", "it") correctly resolved
  - Target: >90%
- **Re-clarification Rate**: % of times AI asks "which task?"
  - Target: <10%
- **Average Conversation Length**: Messages before context loss
  - Target: 8-10 turns (with 13-window, allows 3-4 AI responses)

### Qualitative
- **User Friction**: "I had to repeat myself" complaints
  - Target: <5% of conversations
- **Natural Flow**: Multi-turn conversations feel coherent
  - Target: >80% user satisfaction
- **Cognitive Load**: Users report lower mental effort
  - Target: Measured via surveys

---

## Future Enhancements

### Phase 4.1: Context Summarization
When context window is full, automatically summarize and compress:
```
Original (13 messages):
1. User: Deploy monitoring
2. Bot: Added task
3. User: How long?
4. Bot: 2 hours
...
13. User: Schedule it Thursday

Compressed (3 messages):
1. [Summary]: User requested monitoring deployment task (2hr, due Thursday)
11. User: Check status
12. Bot: Not started yet
13. User: Remind me tomorrow
```

### Phase 4.2: Long-Term Memory
Store "facts" separately from conversation:
```sql
CREATE TABLE user_facts (
  user_id TEXT,
  fact_type TEXT,  -- preference, constraint, goal
  fact TEXT,       -- "Prefers morning focus blocks"
  confidence REAL, -- 0.0-1.0
  last_mentioned TIMESTAMP
);
```

### Phase 4.3: Context-Aware Tool Routing
Use conversation history to improve tool selection:
```
Context: Last 3 messages were about tasks
User: "How much will it cost?"
AI: Likely asking about task cost, not general finance → Call ADHD_Commander, not Finance_Manager
```

### Phase 4.4: Multi-Modal Context
Include screenshots, documents in context:
```
User: [Uploads screenshot of error]
User: How do I fix this?
AI: [References screenshot from 2 messages ago]
```

---

## Conclusion

Phase 4 Memory & Context transforms the Supervisor Agent from a stateless command processor into a **conversational partner** that:
- Remembers recent interactions
- Resolves contextual references ("that task", "it")
- Maintains coherent multi-turn conversations
- Reduces cognitive load (critical for ADHD users)

The 13-message window balances context depth with performance, and automatic pruning prevents unbounded growth. Combined with PostgreSQL persistence, the system provides reliable, restart-resilient conversation memory.
