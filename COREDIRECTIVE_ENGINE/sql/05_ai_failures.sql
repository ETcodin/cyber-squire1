-- Phase 5: Fallback & Resilience - Database Schema
-- File: COREDIRECTIVE_ENGINE/sql/05_ai_failures.sql
-- Purpose: Track AI provider failures and enable escalation logic

-- =============================================================================
-- Table: ai_failures
-- Description: Logs all AI provider failures for monitoring and escalation
-- =============================================================================

CREATE TABLE IF NOT EXISTS ai_failures (
  -- Primary key
  id SERIAL PRIMARY KEY,

  -- Failure context
  chat_id VARCHAR(50) NOT NULL,                    -- Telegram chat ID
  message_id BIGINT,                               -- Telegram message ID that triggered failure

  -- Failure classification
  failure_type VARCHAR(20) NOT NULL,               -- 'timeout', 'error', 'quota', 'complete_failure'
  provider VARCHAR(20) NOT NULL,                   -- 'ollama', 'gemini', 'none'
  error_detail TEXT,                               -- Error message or stack trace

  -- Timestamps
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),      -- When failure occurred
  resolved BOOLEAN DEFAULT FALSE,                  -- Auto-resolved by trigger after 1 hour
  resolved_at TIMESTAMP,                           -- When auto-resolved

  -- Constraints
  CONSTRAINT valid_failure_type CHECK (
    failure_type IN ('timeout', 'error', 'quota', 'complete_failure', 'ollama_timeout', 'test_failure', 'new_failure')
  ),
  CONSTRAINT valid_provider CHECK (
    provider IN ('ollama', 'gemini', 'none', 'test_provider')
  )
);

-- =============================================================================
-- Indexes
-- =============================================================================

-- Query recent failures by chat (for escalation check)
CREATE INDEX IF NOT EXISTS idx_ai_failures_chat_time
  ON ai_failures(chat_id, timestamp DESC);

-- Query unresolved failures
CREATE INDEX IF NOT EXISTS idx_ai_failures_unresolved
  ON ai_failures(resolved)
  WHERE resolved = FALSE;

-- Query failures by provider (for reliability metrics)
CREATE INDEX IF NOT EXISTS idx_ai_failures_provider
  ON ai_failures(provider, timestamp DESC);

-- =============================================================================
-- Auto-Resolution Function
-- Description: Marks failures older than 1 hour as resolved
-- Trigger: Fires after each INSERT to keep table clean
-- =============================================================================

CREATE OR REPLACE FUNCTION auto_resolve_old_failures()
RETURNS TRIGGER AS $$
BEGIN
  -- Update old unresolved failures
  UPDATE ai_failures
  SET
    resolved = TRUE,
    resolved_at = NOW()
  WHERE
    timestamp < NOW() - INTERVAL '1 hour'
    AND resolved = FALSE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_auto_resolve_failures ON ai_failures;

CREATE TRIGGER trigger_auto_resolve_failures
  AFTER INSERT ON ai_failures
  FOR EACH STATEMENT
  EXECUTE FUNCTION auto_resolve_old_failures();

-- =============================================================================
-- Utility Queries
-- =============================================================================

-- Query: Check for escalation conditions (3+ failures in 10 minutes)
-- Usage: Run before sending message response to check if escalation needed
COMMENT ON TABLE ai_failures IS 'Escalation Query:
SELECT
  chat_id,
  COUNT(*) as consecutive_failures,
  MAX(timestamp) as last_failure
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL ''10 minutes''
  AND resolved = FALSE
GROUP BY chat_id
HAVING COUNT(*) >= 3;';

-- =============================================================================
-- Monitoring Queries
-- =============================================================================

-- Daily Fallback Metrics
CREATE OR REPLACE VIEW v_daily_fallback_metrics AS
SELECT
  DATE_TRUNC('day', timestamp) as day,
  COUNT(*) FILTER (WHERE provider = 'ollama') as ollama_failures,
  COUNT(*) FILTER (WHERE provider = 'gemini') as gemini_failures,
  COUNT(*) as total_failures,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE provider = 'gemini') /
    NULLIF(COUNT(*), 0),
    2
  ) as gemini_usage_pct
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY day
ORDER BY day DESC;

-- Hourly Failure Rate
CREATE OR REPLACE VIEW v_hourly_failure_rate AS
SELECT
  DATE_TRUNC('hour', timestamp) as hour,
  COUNT(*) as failures,
  COUNT(DISTINCT chat_id) as affected_chats,
  STRING_AGG(DISTINCT failure_type, ', ') as failure_types
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour DESC;

-- Current Escalation Status
CREATE OR REPLACE VIEW v_escalation_status AS
SELECT
  chat_id,
  COUNT(*) as failure_count,
  MAX(timestamp) as last_failure,
  MIN(timestamp) as first_failure,
  STRING_AGG(DISTINCT failure_type, ', ') as failure_types,
  STRING_AGG(DISTINCT provider, ', ') as providers_failed
FROM ai_failures
WHERE timestamp > NOW() - INTERVAL '10 minutes'
  AND resolved = FALSE
GROUP BY chat_id
HAVING COUNT(*) >= 3
ORDER BY failure_count DESC;

-- =============================================================================
-- Sample Data for Testing
-- =============================================================================

-- IMPORTANT: Only run in development/testing environments
-- Uncomment to insert test data:

-- INSERT INTO ai_failures (chat_id, failure_type, provider, message_id, error_detail, timestamp)
-- VALUES
--   ('test_chat_1', 'ollama_timeout', 'ollama', 100001, 'Fallback to Gemini successful', NOW() - INTERVAL '5 minutes'),
--   ('test_chat_1', 'ollama_timeout', 'ollama', 100002, 'Fallback to Gemini successful', NOW() - INTERVAL '3 minutes'),
--   ('test_chat_1', 'complete_failure', 'gemini', 100003, 'Gemini quota exhausted', NOW() - INTERVAL '1 minute'),
--   ('test_chat_2', 'quota', 'gemini', 100004, 'Rate limit exceeded', NOW() - INTERVAL '30 minutes');

-- =============================================================================
-- Cleanup Queries
-- =============================================================================

-- Manually resolve all old failures (if auto-trigger fails)
-- UPDATE ai_failures
-- SET resolved = TRUE, resolved_at = NOW()
-- WHERE timestamp < NOW() - INTERVAL '1 hour'
--   AND resolved = FALSE;

-- Purge very old resolved failures (older than 30 days)
-- DELETE FROM ai_failures
-- WHERE resolved = TRUE
--   AND resolved_at < NOW() - INTERVAL '30 days';

-- =============================================================================
-- Grants (if using separate app user)
-- =============================================================================

-- GRANT SELECT, INSERT ON ai_failures TO n8n;
-- GRANT USAGE, SELECT ON SEQUENCE ai_failures_id_seq TO n8n;

-- =============================================================================
-- Verification
-- =============================================================================

-- Verify table structure
-- \d ai_failures

-- Verify indexes
-- \di ai_failures*

-- Verify trigger
-- SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'ai_failures'::regclass;

-- Verify views
-- SELECT * FROM v_daily_fallback_metrics LIMIT 5;
-- SELECT * FROM v_hourly_failure_rate LIMIT 10;
-- SELECT * FROM v_escalation_status;

-- =============================================================================
-- End of Schema
-- =============================================================================
