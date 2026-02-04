# ADHD Commander Setup Guide

## Architecture Overview

```
Telegram Bot
    │
    ▼
┌─────────────────────────────┐
│  Master Router v3           │
│  (workflow_master_router_   │
│   v3.json)                  │
├─────────────────────────────┤
│  Routes:                    │
│  /focus → ADHD Commander    │
│  /status → Inline response  │
│  /help → Inline response    │
│  /warroom → Coming soon     │
└─────────────────────────────┘
            │
            ▼ Execute Workflow
┌─────────────────────────────┐
│  ADHD Commander             │
│  (workflow_adhd_commander.  │
│   json)                     │
├─────────────────────────────┤
│  1. Query Notion tasks      │
│  2. Ollama picks best task  │
│  3. Send via Telegram       │
│  4. Log to PostgreSQL       │
└─────────────────────────────┘
```

## Required Environment Variables

Set these in n8n Settings → Variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `NOTION_TASKS_DB_ID` | Your Notion database ID | `abc123...` |
| `ADHD_COMMANDER_WORKFLOW_ID` | Workflow ID after import | `42` |

## Import Order

1. **Import ADHD Commander first** (`workflow_adhd_commander.json`)
   - Note the workflow ID assigned by n8n
   - Set `ADHD_COMMANDER_WORKFLOW_ID` environment variable

2. **Import Master Router v3** (`workflow_master_router_v3.json`)
   - Activate and replace old Master Router

3. **Run PostgreSQL migration**
   ```bash
   psql -h localhost -U cd_user -d cd_ops -f sql/commander_log.sql
   ```

## Notion Database Requirements

Your Notion tasks database needs these properties:

| Property | Type | Values |
|----------|------|--------|
| Name | Title | Task name |
| Status | Select | Backlog, In Progress, Done |
| Priority | Select | High, Medium, Low |
| Due Date | Date | Optional |

## Credential IDs (Pre-configured)

- `notion-cred` - Notion API connection
- `telegram-bot-main` - Telegram Bot token
- `cd-postgres-main` - PostgreSQL connection

## Testing

1. Send `/focus` to your Telegram bot
2. Verify Notion tasks are queried
3. Check Ollama responds with task selection
4. Confirm PostgreSQL logging

## ROI Check

- **Time saved:** 15-20 min/day of decision paralysis
- **Cost:** $0 (Notion free tier + Ollama local + Telegram free)
- **Focus:** Single task deployment, no visual overwhelm
