-- NUCLEAR WIPE: Kill all n8n workflow cache
-- Execute on cd-service-db as cduser

-- Step 1: Delete all workflows (kills ghost triggers)
DELETE FROM workflow_entity;

-- Step 2: Truncate webhook paths
TRUNCATE webhook_entity;

-- Step 3: Clear execution history to prevent stale references
TRUNCATE execution_entity CASCADE;

-- Step 4: Reset nuclear_log for clean slate
TRUNCATE nuclear_log;

-- Verify clean state
SELECT 'workflow_entity' as tbl, COUNT(*) as rows FROM workflow_entity
UNION ALL
SELECT 'webhook_entity', COUNT(*) FROM webhook_entity
UNION ALL
SELECT 'execution_entity', COUNT(*) FROM execution_entity
UNION ALL
SELECT 'nuclear_log', COUNT(*) FROM nuclear_log;
