# Message Deduplication Reference

**System:** Telegram Supervisor Agent v2
**Database:** cd_automation_db (PostgreSQL 16)
**Implementation Date:** 2026-02-04

## Quick Overview

This system prevents duplicate message processing during Telegram message bursts using PostgreSQL-based atomic deduplication.

## Architecture

```
Telegram → Extract ID → Check Duplicate (DB INSERT) → If Duplicate?
                                                        ├─ YES → Skip (log)
                                                        └─ NO → Process → Respond → Mark Complete
```

## Database Table

**Table:** `telegram_message_log`

| Column | Type | Purpose |
|--------|------|---------|
| message_id | BIGINT (PK) | Telegram message ID (dedup key) |
| chat_id | BIGINT | Chat where message sent |
| user_id | BIGINT | User who sent message |
| message_text | TEXT | Message content (debug) |
| received_at | TIMESTAMP | When message arrived |
| processed_at | TIMESTAMP | When processing completed |
| status | VARCHAR(20) | pending → processing → completed/failed |

**Indexes:**
- Primary Key on `message_id` (enables ON CONFLICT)
- `idx_message_log_received` (for cleanup queries)
- `idx_message_log_chat` (for chat history)
- `idx_message_log_status` (for monitoring)

## How It Works

### First Message (message_id=12345)
```sql
INSERT INTO telegram_message_log (message_id, chat_id, user_id, message_text, status)
VALUES (12345, 789, 101, 'Hello', 'processing')
ON CONFLICT (message_id) DO NOTHING
RETURNING message_id;
-- Result: Returns 12345 (insert successful)
-- Action: Message proceeds to AI processing
```

### Duplicate Message (same message_id=12345)
```sql
INSERT INTO telegram_message_log (message_id, chat_id, user_id, message_text, status)
VALUES (12345, 789, 101, 'Hello', 'processing')
ON CONFLICT (message_id) DO NOTHING
RETURNING message_id;
-- Result: Returns empty (conflict on primary key)
-- Action: Message skipped (logged to console)
```

## Monitoring Queries

### Check Recent Duplicates
```sql
SELECT chat_id, message_id, COUNT(*) as attempts
FROM telegram_message_log
WHERE received_at > NOW() - INTERVAL '1 hour'
GROUP BY chat_id, message_id
HAVING COUNT(*) > 1;
```

### View Processing Stats
```sql
SELECT * FROM message_log_stats;
-- Shows: status, count, oldest, newest, avg_processing_seconds
```

### Check Stuck Messages
```sql
SELECT message_id, chat_id, received_at
FROM telegram_message_log
WHERE status = 'processing'
  AND received_at < NOW() - INTERVAL '5 minutes';
-- These may need manual intervention
```

## Maintenance

### Manual Cleanup (removes messages >24h old)
```sql
SELECT cleanup_old_messages();
-- Returns number of rows deleted
```

### Recommended Cron Schedule
```
0 3 * * * - Daily at 3am
```

### Force Complete Stuck Message
```sql
UPDATE telegram_message_log
SET status = 'completed', processed_at = NOW()
WHERE message_id = 12345;
```

## Workflow Nodes Reference

| Node Name | Type | Purpose |
|-----------|------|---------|
| Telegram Ingestion | telegramTrigger | Webhook entry point |
| Extract Message ID | code | Parse message_id from webhook |
| Check Duplicate | postgres | INSERT with ON CONFLICT |
| Is Duplicate? | if | Route based on INSERT result |
| Skip Duplicate | code | Log and terminate (duplicate path) |
| Parse Input | code | Normalize data (new message path) |
| Supervisor Agent | agent | AI processing |
| Format Output | code | Prepare response |
| Send Response | telegram | Reply to user |
| Mark Complete | postgres | UPDATE status to completed |

## Error Handling

### Missing message_id
- **Behavior:** Throws error in Extract Message ID node
- **Action:** Fails fast, no database write

### Database Connection Failure
- **Behavior:** Check Duplicate node fails
- **Action:** Message not processed (n8n error workflow triggered)

### Concurrent Identical Messages
- **Behavior:** PostgreSQL serialization handles race
- **Action:** Only first INSERT succeeds, others skip

## Testing

### Manual Test
1. Send message to Telegram bot: "test deduplication"
2. Immediately send same message 2 more times (within 1 second)
3. Expected: Receive only 1 response

### Verification Query
```sql
SELECT message_id, COUNT(*) as log_count
FROM telegram_message_log
WHERE message_text LIKE '%test deduplication%'
GROUP BY message_id;
-- Expected: log_count = 1
```

### Load Test
```bash
# Send 10 identical messages
for i in {1..10}; do
  curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
    -d "chat_id=<CHAT_ID>" \
    -d "text=Load test message" &
done
wait
# Expected: Only 1 processed (9 duplicates skipped)
```

## Connection Information

**Database:** cd_automation_db
**Host:** localhost (from within cd-service-db container)
**Port:** 5432 (internal), not exposed externally
**User:** tigoue_architect
**Password:** @tim32win!

**Access from EC2:**
```bash
docker exec -it cd-service-db psql -U tigoue_architect -d cd_automation_db
```

**n8n Credential:** `cd-postgres-main`

## Success Criteria Met

- **SC-2.2 (Burst Handling):** Messages arriving in rapid succession are queued and deduplicated atomically
- **SC-2.4 (No Duplicates):** Primary key constraint prevents duplicate processing at database level

## Rollback Plan

If deduplication causes issues:

1. **Restore old workflow:**
   ```bash
   cp COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json.backup \
      COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json
   ```

2. **Drop table (optional, causes data loss):**
   ```sql
   DROP TABLE telegram_message_log CASCADE;
   ```

3. **Re-import workflow to n8n**

## Files

- **Schema:** `COREDIRECTIVE_ENGINE/sql/create_message_log.sql`
- **Workflow:** `COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json`
- **Backup:** `COREDIRECTIVE_ENGINE/workflow_supervisor_agent.json.backup`
- **Summary:** `.planning/phases/02-webhook-message-intake/02-02-SUMMARY.md`
- **This File:** `COREDIRECTIVE_ENGINE/MESSAGE_DEDUPLICATION_REFERENCE.md`

## Support

**Troubleshooting:**
1. Check n8n execution log for "DUPLICATE_SKIPPED" messages
2. Query `message_log_stats` view for anomalies
3. Verify PostgreSQL credentials in n8n (`cd-postgres-main`)
4. Check database connection: `docker exec cd-service-db pg_isready`

**Common Issues:**
- "Role postgres does not exist" → Use `tigoue_architect` user
- "Database coredirective does not exist" → Use `cd_automation_db`
- "Table already exists" → Schema is idempotent, safe to re-run

---

**Version:** 1.0
**Author:** Plan 02-02 Execution
**Last Updated:** 2026-02-04
