-- ADHD Commander Log Table
-- Tracks all focus dispatches for analytics and session counting

CREATE TABLE IF NOT EXISTS commander_log (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL DEFAULT 'focus_dispatch',
    task_name VARCHAR(255),
    duration_minutes INTEGER DEFAULT 45,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Index for weekly session counting
CREATE INDEX IF NOT EXISTS idx_commander_log_created_at
ON commander_log(created_at);

-- Index for task analytics
CREATE INDEX IF NOT EXISTS idx_commander_log_task_name
ON commander_log(task_name);

-- View for weekly session count (12WY lead measure)
CREATE OR REPLACE VIEW weekly_focus_sessions AS
SELECT
    DATE_TRUNC('week', created_at) AS week_start,
    COUNT(*) AS total_sessions,
    COUNT(*) FILTER (WHERE completed = TRUE) AS completed_sessions,
    ROUND(AVG(duration_minutes)) AS avg_duration,
    SUM(duration_minutes) AS total_focus_minutes
FROM commander_log
WHERE event_type = 'focus_dispatch'
GROUP BY DATE_TRUNC('week', created_at)
ORDER BY week_start DESC;

-- Function to get current week's session count
CREATE OR REPLACE FUNCTION get_weekly_session_count()
RETURNS INTEGER AS $$
    SELECT COUNT(*)::INTEGER
    FROM commander_log
    WHERE event_type = 'focus_dispatch'
    AND created_at >= DATE_TRUNC('week', NOW());
$$ LANGUAGE SQL;
