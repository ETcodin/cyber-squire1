-- routing_metrics.sql
-- PostgreSQL schema for AI routing analytics and confidence tracking
-- Part of Phase 03-03: Confidence Threshold & Fallback Handling
-- Created: 2026-02-04

-- ============================================================================
-- TABLE: routing_decisions
-- Tracks every routing decision with multi-signal confidence estimation
-- ============================================================================

CREATE TABLE IF NOT EXISTS routing_decisions (
    id SERIAL PRIMARY KEY,

    -- Execution context
    execution_id VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    chat_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50),
    message_id BIGINT,

    -- Input analysis
    input_text TEXT,
    input_length INT,
    keywords_found TEXT[], -- Array of matched keywords
    fallback_triggers TEXT[], -- Array of fallback trigger reasons

    -- Routing decision
    tools_called TEXT[], -- Array of tool names invoked
    tool_count INT DEFAULT 0,
    is_fallback_response BOOLEAN DEFAULT FALSE,

    -- Confidence scoring (multi-signal)
    confidence_score INT CHECK (confidence_score >= 0 AND confidence_score <= 100),
    confidence_level VARCHAR(10) CHECK (confidence_level IN ('LOW', 'MEDIUM', 'HIGH')),
    signal_tool INT, -- Tool usage signal (0-100)
    signal_keywords INT, -- Keyword match signal (0-100)
    signal_length INT, -- Input length signal (0-100)
    signal_specificity INT, -- Response specificity signal (0-100)

    -- Response metadata
    response_length INT,
    response_text TEXT, -- Optional: store for analysis (consider privacy)

    -- Performance
    latency_ms INT,

    -- Indexes for common queries
    CONSTRAINT routing_decisions_chat_id_idx_key UNIQUE (execution_id)
);

-- Indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_routing_timestamp ON routing_decisions(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_routing_chat_id ON routing_decisions(chat_id);
CREATE INDEX IF NOT EXISTS idx_routing_confidence_level ON routing_decisions(confidence_level);
CREATE INDEX IF NOT EXISTS idx_routing_tools ON routing_decisions USING GIN(tools_called);
CREATE INDEX IF NOT EXISTS idx_routing_fallback ON routing_decisions(is_fallback_response) WHERE is_fallback_response = TRUE;

-- ============================================================================
-- TABLE: confidence_threshold_events
-- Tracks when confidence thresholds trigger specific behaviors
-- ============================================================================

CREATE TABLE IF NOT EXISTS confidence_threshold_events (
    id SERIAL PRIMARY KEY,
    routing_decision_id INT REFERENCES routing_decisions(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    threshold_type VARCHAR(20) CHECK (threshold_type IN ('HIGH', 'MEDIUM', 'LOW')),
    action_taken VARCHAR(50), -- 'direct_tool_call', 'clarification_question', 'fallback_response'

    -- Context
    input_snippet TEXT, -- First 200 chars for debugging
    response_snippet TEXT,

    -- For A/B testing and tuning
    expected_threshold VARCHAR(20),
    actual_threshold VARCHAR(20),
    threshold_match BOOLEAN GENERATED ALWAYS AS (expected_threshold = actual_threshold) STORED
);

CREATE INDEX IF NOT EXISTS idx_threshold_timestamp ON confidence_threshold_events(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_threshold_type ON confidence_threshold_events(threshold_type);

-- ============================================================================
-- TABLE: fallback_patterns
-- Aggregates common fallback patterns for model tuning
-- ============================================================================

CREATE TABLE IF NOT EXISTS fallback_patterns (
    id SERIAL PRIMARY KEY,
    pattern_hash VARCHAR(64) UNIQUE NOT NULL, -- MD5 of normalized input

    -- Pattern characteristics
    input_pattern TEXT, -- Anonymized/normalized pattern
    trigger_type VARCHAR(30), -- 'too_short', 'emoji_only', 'random_characters', 'no_keywords'
    occurrence_count INT DEFAULT 1,

    -- Statistics
    first_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    avg_confidence_score DECIMAL(5,2),

    -- Resolution tracking
    user_clarified BOOLEAN DEFAULT FALSE, -- Did user provide clarification?
    resolved_tool VARCHAR(50), -- Which tool was eventually used?

    CONSTRAINT fallback_patterns_occurrence_count_check CHECK (occurrence_count > 0)
);

CREATE INDEX IF NOT EXISTS idx_fallback_trigger_type ON fallback_patterns(trigger_type);
CREATE INDEX IF NOT EXISTS idx_fallback_last_seen ON fallback_patterns(last_seen DESC);

-- ============================================================================
-- TABLE: tool_routing_accuracy
-- Tracks routing accuracy per tool for continuous improvement
-- ============================================================================

CREATE TABLE IF NOT EXISTS tool_routing_accuracy (
    id SERIAL PRIMARY KEY,
    tool_name VARCHAR(50) NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Routing stats
    total_calls INT DEFAULT 0,
    high_confidence_calls INT DEFAULT 0, -- >= 70%
    medium_confidence_calls INT DEFAULT 0, -- 40-69%
    low_confidence_calls INT DEFAULT 0, -- < 40%

    -- User feedback (manual tracking via /feedback command - future enhancement)
    positive_feedback INT DEFAULT 0,
    negative_feedback INT DEFAULT 0,

    -- Calculated metrics
    avg_confidence DECIMAL(5,2),
    success_rate DECIMAL(5,2), -- positive_feedback / (positive_feedback + negative_feedback)

    CONSTRAINT tool_routing_accuracy_unique_tool_date UNIQUE (tool_name, date)
);

CREATE INDEX IF NOT EXISTS idx_tool_accuracy_date ON tool_routing_accuracy(date DESC);
CREATE INDEX IF NOT EXISTS idx_tool_accuracy_name ON tool_routing_accuracy(tool_name);

-- ============================================================================
-- ANALYTICS QUERIES
-- Common queries for monitoring and optimization
-- ============================================================================

-- View: Daily routing performance summary
CREATE OR REPLACE VIEW v_daily_routing_summary AS
SELECT
    DATE(timestamp) AS date,
    COUNT(*) AS total_decisions,
    COUNT(*) FILTER (WHERE confidence_level = 'HIGH') AS high_confidence,
    COUNT(*) FILTER (WHERE confidence_level = 'MEDIUM') AS medium_confidence,
    COUNT(*) FILTER (WHERE confidence_level = 'LOW') AS low_confidence,
    COUNT(*) FILTER (WHERE is_fallback_response = TRUE) AS fallback_responses,
    ROUND(AVG(confidence_score), 2) AS avg_confidence_score,
    ROUND(AVG(latency_ms), 0) AS avg_latency_ms
FROM routing_decisions
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- View: Tool usage breakdown with confidence
CREATE OR REPLACE VIEW v_tool_usage_with_confidence AS
SELECT
    UNNEST(tools_called) AS tool_name,
    COUNT(*) AS call_count,
    ROUND(AVG(confidence_score), 2) AS avg_confidence,
    COUNT(*) FILTER (WHERE confidence_level = 'HIGH') AS high_conf_count,
    COUNT(*) FILTER (WHERE confidence_level = 'MEDIUM') AS med_conf_count,
    COUNT(*) FILTER (WHERE confidence_level = 'LOW') AS low_conf_count
FROM routing_decisions
WHERE tools_called IS NOT NULL AND ARRAY_LENGTH(tools_called, 1) > 0
GROUP BY tool_name
ORDER BY call_count DESC;

-- View: Fallback trigger analysis
CREATE OR REPLACE VIEW v_fallback_trigger_analysis AS
SELECT
    UNNEST(fallback_triggers) AS trigger_type,
    COUNT(*) AS occurrence_count,
    ROUND(AVG(confidence_score), 2) AS avg_confidence,
    COUNT(*) FILTER (WHERE is_fallback_response = TRUE) AS resulted_in_fallback
FROM routing_decisions
WHERE fallback_triggers IS NOT NULL AND ARRAY_LENGTH(fallback_triggers, 1) > 0
GROUP BY trigger_type
ORDER BY occurrence_count DESC;

-- ============================================================================
-- SAMPLE ANALYTICS QUERIES
-- Copy/paste these for ad-hoc analysis
-- ============================================================================

-- Query 1: Last 24 hours routing performance
-- SELECT * FROM v_daily_routing_summary WHERE date >= CURRENT_DATE - INTERVAL '1 day';

-- Query 2: Find low-confidence decisions that didn't trigger fallback (potential issues)
-- SELECT execution_id, input_text, confidence_score, tools_called, response_length
-- FROM routing_decisions
-- WHERE confidence_level = 'LOW' AND is_fallback_response = FALSE
-- ORDER BY timestamp DESC LIMIT 50;

-- Query 3: Most common fallback patterns
-- SELECT pattern_hash, input_pattern, trigger_type, occurrence_count, last_seen
-- FROM fallback_patterns
-- ORDER BY occurrence_count DESC LIMIT 20;

-- Query 4: Confidence signal correlation (which signal is most predictive?)
-- SELECT
--     confidence_level,
--     ROUND(AVG(signal_tool), 2) AS avg_tool_signal,
--     ROUND(AVG(signal_keywords), 2) AS avg_keyword_signal,
--     ROUND(AVG(signal_length), 2) AS avg_length_signal,
--     ROUND(AVG(signal_specificity), 2) AS avg_specificity_signal
-- FROM routing_decisions
-- GROUP BY confidence_level
-- ORDER BY confidence_level DESC;

-- Query 5: Hourly traffic pattern (when is the system busiest?)
-- SELECT
--     EXTRACT(HOUR FROM timestamp) AS hour,
--     COUNT(*) AS decision_count,
--     ROUND(AVG(confidence_score), 2) AS avg_confidence
-- FROM routing_decisions
-- WHERE timestamp >= NOW() - INTERVAL '7 days'
-- GROUP BY hour
-- ORDER BY hour;

-- ============================================================================
-- MAINTENANCE FUNCTIONS
-- ============================================================================

-- Function: Update fallback pattern statistics
CREATE OR REPLACE FUNCTION update_fallback_pattern(
    p_input_text TEXT,
    p_trigger_type VARCHAR(30),
    p_confidence_score INT,
    p_resolved_tool VARCHAR(50) DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_pattern_hash VARCHAR(64);
    v_normalized_input TEXT;
BEGIN
    -- Normalize input (lowercase, remove extra spaces)
    v_normalized_input := LOWER(TRIM(REGEXP_REPLACE(p_input_text, '\s+', ' ', 'g')));
    v_pattern_hash := MD5(v_normalized_input);

    INSERT INTO fallback_patterns (pattern_hash, input_pattern, trigger_type, avg_confidence_score, resolved_tool)
    VALUES (v_pattern_hash, v_normalized_input, p_trigger_type, p_confidence_score, p_resolved_tool)
    ON CONFLICT (pattern_hash) DO UPDATE SET
        occurrence_count = fallback_patterns.occurrence_count + 1,
        last_seen = NOW(),
        avg_confidence_score = (fallback_patterns.avg_confidence_score * fallback_patterns.occurrence_count + p_confidence_score)
                                / (fallback_patterns.occurrence_count + 1),
        resolved_tool = COALESCE(EXCLUDED.resolved_tool, fallback_patterns.resolved_tool),
        user_clarified = CASE WHEN EXCLUDED.resolved_tool IS NOT NULL THEN TRUE ELSE fallback_patterns.user_clarified END;
END;
$$ LANGUAGE plpgsql;

-- Function: Update daily tool accuracy stats
CREATE OR REPLACE FUNCTION update_tool_accuracy(
    p_tool_name VARCHAR(50),
    p_confidence_score INT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO tool_routing_accuracy (tool_name, date, total_calls, avg_confidence,
                                       high_confidence_calls, medium_confidence_calls, low_confidence_calls)
    VALUES (p_tool_name, CURRENT_DATE, 1, p_confidence_score,
            CASE WHEN p_confidence_score >= 70 THEN 1 ELSE 0 END,
            CASE WHEN p_confidence_score >= 40 AND p_confidence_score < 70 THEN 1 ELSE 0 END,
            CASE WHEN p_confidence_score < 40 THEN 1 ELSE 0 END)
    ON CONFLICT (tool_name, date) DO UPDATE SET
        total_calls = tool_routing_accuracy.total_calls + 1,
        avg_confidence = (tool_routing_accuracy.avg_confidence * tool_routing_accuracy.total_calls + p_confidence_score)
                         / (tool_routing_accuracy.total_calls + 1),
        high_confidence_calls = tool_routing_accuracy.high_confidence_calls +
                                CASE WHEN p_confidence_score >= 70 THEN 1 ELSE 0 END,
        medium_confidence_calls = tool_routing_accuracy.medium_confidence_calls +
                                  CASE WHEN p_confidence_score >= 40 AND p_confidence_score < 70 THEN 1 ELSE 0 END,
        low_confidence_calls = tool_routing_accuracy.low_confidence_calls +
                               CASE WHEN p_confidence_score < 40 THEN 1 ELSE 0 END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INITIAL DATA / EXAMPLE
-- ============================================================================

-- Example: Insert a sample routing decision (for testing)
-- INSERT INTO routing_decisions (
--     execution_id, chat_id, user_id, input_text, input_length,
--     keywords_found, tools_called, tool_count, confidence_score, confidence_level,
--     signal_tool, signal_keywords, signal_length, signal_specificity,
--     response_length, is_fallback_response
-- ) VALUES (
--     'test-exec-001', '123456789', 'user123', 'What should I work on?', 23,
--     ARRAY['what', 'work'], ARRAY['ADHD_Commander'], 1, 85, 'HIGH',
--     100, 50, 70, 80, 156, FALSE
-- );

-- Grant permissions (adjust user as needed)
-- GRANT SELECT, INSERT, UPDATE ON routing_decisions TO n8n_user;
-- GRANT SELECT, INSERT, UPDATE ON confidence_threshold_events TO n8n_user;
-- GRANT SELECT, INSERT, UPDATE ON fallback_patterns TO n8n_user;
-- GRANT SELECT, INSERT, UPDATE ON tool_routing_accuracy TO n8n_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO n8n_user;

COMMENT ON TABLE routing_decisions IS 'Tracks all AI routing decisions with multi-signal confidence scoring';
COMMENT ON TABLE confidence_threshold_events IS 'Logs threshold-based behavior triggers (HIGH/MEDIUM/LOW confidence actions)';
COMMENT ON TABLE fallback_patterns IS 'Aggregates common fallback patterns for model tuning and optimization';
COMMENT ON TABLE tool_routing_accuracy IS 'Daily accuracy metrics per tool for continuous improvement';
