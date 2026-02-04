-- Chat Memory Table for n8n Postgres Chat Memory Node
-- Optimized for 8GB RAM with 13-message context window
-- Database: cd-service-db

-- Main chat memory table
CREATE TABLE IF NOT EXISTS chat_memory (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Critical index: session lookups must be fast for every message
CREATE INDEX IF NOT EXISTS idx_chat_memory_session_id
ON chat_memory(session_id);

-- Index for window pruning (ORDER BY created_at DESC LIMIT 13)
CREATE INDEX IF NOT EXISTS idx_chat_memory_session_created
ON chat_memory(session_id, created_at DESC);

-- Function: Prune messages beyond 13-window per session
-- This prevents unbounded memory growth
CREATE OR REPLACE FUNCTION prune_chat_memory_window()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete messages beyond the 13-message window for this session
    DELETE FROM chat_memory
    WHERE id IN (
        SELECT id FROM chat_memory
        WHERE session_id = NEW.session_id
        ORDER BY created_at DESC
        OFFSET 13
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Auto-prune after every insert
DROP TRIGGER IF EXISTS trigger_prune_chat_memory ON chat_memory;
CREATE TRIGGER trigger_prune_chat_memory
    AFTER INSERT ON chat_memory
    FOR EACH ROW
    EXECUTE FUNCTION prune_chat_memory_window();

-- Function: Get context window for a session (used by n8n)
CREATE OR REPLACE FUNCTION get_chat_context(p_session_id VARCHAR(255))
RETURNS TABLE (
    role VARCHAR(20),
    content TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
    SELECT role, content, created_at
    FROM chat_memory
    WHERE session_id = p_session_id
    ORDER BY created_at ASC
    LIMIT 13;
$$ LANGUAGE SQL;

-- Weekly maintenance: Clean stale sessions (>7 days inactive)
-- Run via pg_cron or n8n scheduled workflow
CREATE OR REPLACE FUNCTION cleanup_stale_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH stale AS (
        SELECT session_id
        FROM chat_memory
        GROUP BY session_id
        HAVING MAX(created_at) < NOW() - INTERVAL '7 days'
    )
    DELETE FROM chat_memory
    WHERE session_id IN (SELECT session_id FROM stale);

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- View: Memory usage per session (for monitoring)
CREATE OR REPLACE VIEW chat_memory_stats AS
SELECT
    session_id,
    COUNT(*) AS message_count,
    MIN(created_at) AS first_message,
    MAX(created_at) AS last_message,
    pg_size_pretty(SUM(LENGTH(content))::bigint) AS content_size
FROM chat_memory
GROUP BY session_id
ORDER BY MAX(created_at) DESC;

-- Grant permissions (adjust role name as needed)
-- GRANT SELECT, INSERT, DELETE ON chat_memory TO n8n_user;
-- GRANT USAGE, SELECT ON SEQUENCE chat_memory_id_seq TO n8n_user;

COMMENT ON TABLE chat_memory IS 'n8n Postgres Chat Memory - 13 message window, auto-pruning';
