# Supervisor Agent Deployment Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    TELEGRAM SUPERVISOR AGENT                     │
├─────────────────────────────────────────────────────────────────┤
│  Telegram → Parse Input → Supervisor Agent → Format → Telegram  │
│                               │                                  │
│              ┌────────────────┼────────────────┐                │
│              ▼                ▼                ▼                │
│        ┌─────────┐    ┌─────────────┐   ┌───────────┐          │
│        │ Ollama  │    │   Postgres  │   │   Tools   │          │
│        │  Qwen   │    │ Chat Memory │   │(Workflows)│          │
│        │  7B     │    │  13-Window  │   │           │          │
│        └─────────┘    └─────────────┘   └───────────┘          │
│                                               │                  │
│                       ┌───────────────────────┼──────────┐      │
│                       ▼                       ▼          ▼      │
│               ┌──────────────┐    ┌──────────────────────────┐  │
│               │    ADHD      │    │        Finance           │  │
│               │  Commander   │    │        Manager           │  │
│               └──────────────┘    └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: Initialize Database

SSH into your server and run:

```bash
docker exec -i cd-service-db psql -U n8n -d n8n <<EOF
$(cat sql/chat_memory_13window.sql)
EOF
```

Or connect via your preferred PostgreSQL client and run `sql/chat_memory_13window.sql`.

**Verify installation:**
```sql
SELECT * FROM chat_memory_stats;
-- Should return empty (no sessions yet)
```

## Step 2: Configure Environment Variables

In n8n Settings → Variables, add:

| Variable | Value | Description |
|----------|-------|-------------|
| `ADHD_COMMANDER_WORKFLOW_ID` | `<workflow-id>` | ID of ADHD Commander workflow |
| `FINANCE_WORKFLOW_ID` | `<workflow-id>` | ID of Financial War Room workflow |
| `NOTION_TASKS_DB_ID` | `<notion-db-id>` | Your Notion tasks database ID |

**To get workflow IDs:**
1. Open the workflow in n8n
2. Look at the URL: `https://your-n8n.com/workflow/<THIS-IS-THE-ID>`

## Step 3: Import Supervisor Workflow

1. Open n8n
2. Create New Workflow
3. Import from File: `workflow_supervisor_agent.json`
4. Verify node connections (see architecture above)

## Step 4: Configure Credentials

Ensure these credentials exist and are properly configured:

| Credential Name | Type | Used By |
|-----------------|------|---------|
| `Telegram Bot` | Telegram API | Ingestion, Response nodes |
| `CD PostgreSQL` | PostgreSQL | Chat Memory node |
| `CD Ollama Local` | Ollama API | Model node |

**Ollama credential settings:**
- Base URL: `http://cd-service-ollama:11434`
- Model: `qwen2.5:7b` (or `qwen2.5-coder:7b-instruct-q4_K_M` for RAM safety)

## Step 5: Update Sub-Workflows

Both sub-workflows need "Inherit from Parent" enabled:

1. Open `ADHD Commander - Focus Selector`
2. Click on `Execute Workflow Trigger` node
3. Ensure "Inherit from parent" is toggled ON
4. Save workflow

Repeat for `Mission: Financial War Room`.

## Step 6: Deactivate Old Router

1. Open `Telegram Master Router`
2. Click the toggle to deactivate
3. Keep it around for rollback if needed

## Step 7: Activate Supervisor

1. Open `Telegram Supervisor Agent`
2. Activate the workflow
3. Test with: `/status` or "what should I work on?"

## RAM Optimization Checklist

For 8GB RAM systems:

- [ ] Ollama using Q4 quantized model (`q4_K_M`)
- [ ] Context window set to exactly 13 messages
- [ ] Auto-pruning trigger is active on chat_memory table
- [ ] Weekly cleanup scheduled (see below)

**Schedule weekly cleanup (optional n8n cron):**
```sql
SELECT cleanup_stale_sessions();
```

## Troubleshooting

### "Chat Memory node fails"
- Check PostgreSQL connection in n8n credentials
- Verify `chat_memory` table exists: `\dt chat_memory`
- Check session_id index exists: `\di idx_chat_memory_session_id`

### "Agent doesn't call tools"
- Verify workflow IDs are correct in environment variables
- Check sub-workflows are active
- Test sub-workflows independently first

### "Slow response times"
- Check Ollama model is loaded: `docker logs cd-service-ollama`
- Verify RAM usage: `docker stats`
- Consider lowering `num_predict` from 512 to 256

### "Context seems lost between messages"
- Verify session_id is consistent: check `chatId` in Parse Input output
- Query chat_memory: `SELECT * FROM chat_memory WHERE session_id = '<your-chat-id>' ORDER BY created_at DESC;`

## Rollback Procedure

If something breaks:

1. Deactivate `Telegram Supervisor Agent`
2. Reactivate `Telegram Master Router`
3. Check logs: n8n → Executions → Filter by failed
