-- Nuclear Log Table for 12WY Operating System
-- Run this on cd-service-postgres (CD PostgreSQL)

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS public;

-- Nuclear log table for all 12WY events
CREATE TABLE IF NOT EXISTS nuclear_log (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Indexes for common queries
    CONSTRAINT nuclear_log_event_type_check CHECK (
        event_type IN (
            'commander_dispatch',
            'commander_complete',
            'commander_skip',
            'warroom_financial',
            'warroom_alert',
            'warroom_weekly',
            'intelligence_pulse',
            '12wy_score',
            'recovery_week',
            'system_health'
        )
    )
);

-- Index for time-series queries
CREATE INDEX IF NOT EXISTS idx_nuclear_log_created_at
    ON nuclear_log (created_at DESC);

-- Index for event type filtering
CREATE INDEX IF NOT EXISTS idx_nuclear_log_event_type
    ON nuclear_log (event_type);

-- Index for JSONB payload queries
CREATE INDEX IF NOT EXISTS idx_nuclear_log_payload
    ON nuclear_log USING GIN (payload);

-- 12WY Weekly Execution Scores
CREATE TABLE IF NOT EXISTS execution_scores (
    id SERIAL PRIMARY KEY,
    week_start DATE NOT NULL UNIQUE,
    week_number INT NOT NULL CHECK (week_number BETWEEN 1 AND 13),
    cycle_quarter VARCHAR(10) NOT NULL, -- Q1, Q2, Q3, Q4

    -- Lead measures
    focus_sessions_completed INT DEFAULT 0,
    focus_sessions_target INT DEFAULT 28,

    -- Lag measures (outcomes)
    tasks_completed INT DEFAULT 0,
    tasks_planned INT DEFAULT 0,

    -- Financial
    debt_payment_made DECIMAL(10,2) DEFAULT 0,
    debt_payment_target DECIMAL(10,2) DEFAULT 0,

    -- Calculated score (0-100)
    execution_score DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE
            WHEN focus_sessions_target = 0 THEN 0
            ELSE LEAST(100, (
                (focus_sessions_completed::DECIMAL / NULLIF(focus_sessions_target, 0) * 60) +
                (tasks_completed::DECIMAL / NULLIF(tasks_planned, 0) * 30) +
                (debt_payment_made::DECIMAL / NULLIF(debt_payment_target, 0) * 10)
            ))
        END
    ) STORED,

    is_recovery_week BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Debt tracking table
CREATE TABLE IF NOT EXISTS debt_accounts (
    id SERIAL PRIMARY KEY,
    vendor VARCHAR(100) NOT NULL,
    account_last4 VARCHAR(4),
    category VARCHAR(20) NOT NULL CHECK (category IN ('credit_card', 'loan', 'other')),

    current_balance DECIMAL(12,2) NOT NULL,
    apr DECIMAL(5,2),
    minimum_payment DECIMAL(10,2),
    due_date DATE,

    original_balance DECIMAL(12,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Financial transactions log
CREATE TABLE IF NOT EXISTS financial_transactions (
    id SERIAL PRIMARY KEY,
    email_id VARCHAR(100),
    vendor VARCHAR(100),
    transaction_type VARCHAR(20) NOT NULL,
    amount DECIMAL(12,2),
    balance DECIMAL(12,2),
    category VARCHAR(30),
    account_last4 VARCHAR(4),
    due_date DATE,
    confidence DECIMAL(3,2),

    raw_subject TEXT,
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- View for 12WY cycle progress
CREATE OR REPLACE VIEW v_12wy_cycle_progress AS
WITH cycle_bounds AS (
    SELECT
        CASE
            WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 3 THEN DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '3 months' - INTERVAL '84 days'
            WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 6 THEN DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '6 months' - INTERVAL '84 days'
            WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 9 THEN DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '9 months' - INTERVAL '84 days'
            ELSE DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '12 months' - INTERVAL '84 days'
        END AS cycle_start,
        CASE
            WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 3 THEN (DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '3 months' - INTERVAL '1 day')::DATE
            WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 6 THEN (DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '6 months' - INTERVAL '1 day')::DATE
            WHEN EXTRACT(MONTH FROM CURRENT_DATE) <= 9 THEN (DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '9 months' - INTERVAL '1 day')::DATE
            ELSE (DATE_TRUNC('year', CURRENT_DATE) + INTERVAL '12 months' - INTERVAL '1 day')::DATE
        END AS cycle_end
)
SELECT
    cb.cycle_start,
    cb.cycle_end,
    EXTRACT(WEEK FROM CURRENT_DATE) - EXTRACT(WEEK FROM cb.cycle_start) + 1 AS current_week,
    cb.cycle_end - CURRENT_DATE AS days_remaining,
    COALESCE(AVG(es.execution_score), 0) AS avg_execution_score,
    COUNT(es.id) AS weeks_tracked
FROM cycle_bounds cb
LEFT JOIN execution_scores es ON es.week_start >= cb.cycle_start AND es.week_start <= cb.cycle_end
GROUP BY cb.cycle_start, cb.cycle_end;

-- Function to update execution score
CREATE OR REPLACE FUNCTION update_execution_score()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-updating timestamps
DROP TRIGGER IF EXISTS trigger_update_execution_score ON execution_scores;
CREATE TRIGGER trigger_update_execution_score
    BEFORE UPDATE ON execution_scores
    FOR EACH ROW
    EXECUTE FUNCTION update_execution_score();

-- Grant permissions (adjust username as needed)
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO cd_user;
-- GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO cd_user;

-- Insert initial debt accounts (customize these)
-- INSERT INTO debt_accounts (vendor, category, current_balance, apr, minimum_payment, original_balance)
-- VALUES
--     ('Chase Sapphire', 'credit_card', 15000, 24.99, 350, 15000),
--     ('Discover It', 'credit_card', 12000, 22.99, 280, 12000),
--     ('Amex Blue', 'credit_card', 8000, 19.99, 200, 8000),
--     ('Student Loan', 'loan', 25000, 5.5, 300, 35000);

COMMENT ON TABLE nuclear_log IS '12-Week Year event log for all Commander/WarRoom/Intelligence operations';
COMMENT ON TABLE execution_scores IS 'Weekly execution scores tracking lead and lag measures';
COMMENT ON TABLE debt_accounts IS 'Active debt accounts for War Room tracking';
