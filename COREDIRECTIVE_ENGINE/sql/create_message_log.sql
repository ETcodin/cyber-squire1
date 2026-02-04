-- Message Log Table for Telegram Message Deduplication
-- Purpose: Prevent duplicate message processing during bursts (SC-2.2, SC-2.4)
-- Database: cd-service-db (coredirective database)

-- Main message log table
CREATE TABLE IF NOT EXISTS telegram_message_log (
    message_id BIGINT PRIMARY KEY,              -- Telegram message_id (unique per bot)
    chat_id BIGINT NOT NULL,                    -- Chat where message was sent
    user_id BIGINT,                             -- Telegram user who sent it
    message_text TEXT,                          -- Message content (for debugging)
    received_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
);

-- Index for cleanup queries (auto-purge old messages)
CREATE INDEX IF NOT EXISTS idx_message_log_received
    ON telegram_message_log(received_at);

-- Index for chat-based queries (user history lookups)
CREATE INDEX IF NOT EXISTS idx_message_log_chat
    ON telegram_message_log(chat_id, received_at DESC);

-- Index for status monitoring
CREATE INDEX IF NOT EXISTS idx_message_log_status
    ON telegram_message_log(status, received_at DESC);

-- Auto-cleanup function: Remove messages older than 24 hours
-- Prevents table bloat while maintaining recent deduplication
CREATE OR REPLACE FUNCTION cleanup_old_messages()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM telegram_message_log
    WHERE received_at < NOW() - INTERVAL '24 hours';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- View: Message processing stats (for monitoring)
CREATE OR REPLACE VIEW message_log_stats AS
SELECT
    status,
    COUNT(*) AS count,
    MIN(received_at) AS oldest,
    MAX(received_at) AS newest,
    AVG(EXTRACT(EPOCH FROM (processed_at - received_at))) AS avg_processing_seconds
FROM telegram_message_log
WHERE received_at > NOW() - INTERVAL '1 hour'
GROUP BY status
ORDER BY status;

-- Grant permissions (adjust role name as needed)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON telegram_message_log TO n8n_user;

COMMENT ON TABLE telegram_message_log IS 'Deduplication log for Telegram messages - prevents duplicate processing during bursts';
COMMENT ON COLUMN telegram_message_log.message_id IS 'Telegram message_id - serves as natural deduplication key';
COMMENT ON COLUMN telegram_message_log.status IS 'pending=queued, processing=active, completed=done, failed=error';

-- Scheduled cleanup (run via pg_cron or n8n scheduled workflow):
-- SELECT cleanup_old_messages();
