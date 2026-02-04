#!/bin/bash
# Phase 4: Memory & Context - Deployment Script
# Deploys PostgreSQL chat memory schema and validates configuration

set -euo pipefail

# Configuration
EC2_HOST="54.234.155.244"
SSH_KEY="${HOME}/.ssh/cyber-squire-ops.pem"
SQL_FILE="/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/sql/chat_memory_13window.sql"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Pre-flight checks
preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check SSH key exists
    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH key not found: $SSH_KEY"
        exit 1
    fi

    # Check SQL file exists
    if [[ ! -f "$SQL_FILE" ]]; then
        log_error "SQL file not found: $SQL_FILE"
        exit 1
    fi

    # Check EC2 connectivity
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 ubuntu@$EC2_HOST "echo connected" &>/dev/null; then
        log_error "Cannot connect to EC2 instance: $EC2_HOST"
        exit 1
    fi

    log_info "Pre-flight checks passed"
}

# Check if PostgreSQL is running
check_postgres() {
    log_info "Checking PostgreSQL status..."

    if ssh -i "$SSH_KEY" ubuntu@$EC2_HOST "docker ps | grep cd-service-db" &>/dev/null; then
        log_info "PostgreSQL container is running"
    else
        log_error "PostgreSQL container is not running"
        exit 1
    fi
}

# Check if schema already exists
check_schema_exists() {
    log_info "Checking if chat_memory table exists..."

    local exists=$(ssh -i "$SSH_KEY" ubuntu@$EC2_HOST \
        "docker exec cd-service-db psql -U postgres -d cd_automation_db -tAc \
        \"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'chat_memory');\"")

    if [[ "$exists" == "t" ]]; then
        log_warn "chat_memory table already exists"
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping schema deployment"
            return 1
        fi
        return 0
    else
        log_info "chat_memory table does not exist, will create"
        return 0
    fi
}

# Deploy schema
deploy_schema() {
    log_info "Deploying chat_memory schema..."

    # Copy SQL file to EC2
    scp -i "$SSH_KEY" "$SQL_FILE" ubuntu@$EC2_HOST:/tmp/chat_memory.sql

    # Execute SQL
    ssh -i "$SSH_KEY" ubuntu@$EC2_HOST << 'EOF'
docker exec -i cd-service-db psql -U postgres -d cd_automation_db < /tmp/chat_memory.sql
rm /tmp/chat_memory.sql
EOF

    if [[ $? -eq 0 ]]; then
        log_info "Schema deployed successfully"
    else
        log_error "Schema deployment failed"
        exit 1
    fi
}

# Validate deployment
validate_deployment() {
    log_info "Validating deployment..."

    # Check table exists
    local table_exists=$(ssh -i "$SSH_KEY" ubuntu@$EC2_HOST \
        "docker exec cd-service-db psql -U postgres -d cd_automation_db -tAc \
        \"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'chat_memory');\"")

    if [[ "$table_exists" != "t" ]]; then
        log_error "Table creation failed"
        exit 1
    fi
    log_info "✓ Table created"

    # Check indexes
    local index_count=$(ssh -i "$SSH_KEY" ubuntu@$EC2_HOST \
        "docker exec cd-service-db psql -U postgres -d cd_automation_db -tAc \
        \"SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'chat_memory';\"")

    if [[ "$index_count" -lt 3 ]]; then
        log_error "Index creation incomplete (expected 3, got $index_count)"
        exit 1
    fi
    log_info "✓ Indexes created ($index_count)"

    # Check trigger
    local trigger_exists=$(ssh -i "$SSH_KEY" ubuntu@$EC2_HOST \
        "docker exec cd-service-db psql -U postgres -d cd_automation_db -tAc \
        \"SELECT EXISTS (SELECT FROM pg_trigger WHERE tgname = 'trigger_prune_chat_memory');\"")

    if [[ "$trigger_exists" != "t" ]]; then
        log_error "Trigger creation failed"
        exit 1
    fi
    log_info "✓ Auto-pruning trigger created"

    # Check functions
    local function_count=$(ssh -i "$SSH_KEY" ubuntu@$EC2_HOST \
        "docker exec cd-service-db psql -U postgres -d cd_automation_db -tAc \
        \"SELECT COUNT(*) FROM information_schema.routines WHERE routine_name IN ('prune_chat_memory_window', 'get_chat_context', 'cleanup_stale_sessions');\"")

    if [[ "$function_count" -ne 3 ]]; then
        log_error "Function creation incomplete (expected 3, got $function_count)"
        exit 1
    fi
    log_info "✓ Functions created (3)"

    # Check view
    local view_exists=$(ssh -i "$SSH_KEY" ubuntu@$EC2_HOST \
        "docker exec cd-service-db psql -U postgres -d cd_automation_db -tAc \
        \"SELECT EXISTS (SELECT FROM information_schema.views WHERE table_name = 'chat_memory_stats');\"")

    if [[ "$view_exists" != "t" ]]; then
        log_error "View creation failed"
        exit 1
    fi
    log_info "✓ Statistics view created"

    log_info "All validation checks passed"
}

# Test auto-pruning
test_auto_pruning() {
    log_info "Testing auto-pruning mechanism..."

    ssh -i "$SSH_KEY" ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db << 'SQL'
-- Clean test session
DELETE FROM chat_memory WHERE session_id = 'test-deploy-session';

-- Insert 20 messages
INSERT INTO chat_memory (session_id, role, content)
SELECT
  'test-deploy-session',
  CASE WHEN n % 2 = 0 THEN 'user' ELSE 'assistant' END,
  'Test message number ' || n
FROM generate_series(1, 20) AS n;

-- Check count (should be 13)
SELECT COUNT(*) AS message_count
FROM chat_memory
WHERE session_id = 'test-deploy-session';

-- Cleanup
DELETE FROM chat_memory WHERE session_id = 'test-deploy-session';
SQL
EOF

    log_info "Auto-pruning test complete"
}

# Check n8n workflow configuration
check_workflow_config() {
    log_info "Checking n8n workflow configuration..."

    # This is informational only - we can't easily check n8n workflow from CLI
    log_warn "Manual verification required:"
    echo "  1. Open n8n UI: http://$EC2_HOST:5678"
    echo "  2. Open 'Telegram Supervisor Agent' workflow"
    echo "  3. Verify 'Chat Memory' node is connected to 'Supervisor Agent'"
    echo "  4. Verify Chat Memory settings:"
    echo "     - Session ID Type: customKey"
    echo "     - Session Key: ={{ \$json.chatId }}"
    echo "     - Table Name: chat_memory"
    echo "     - Context Window Length: 13"
    echo "     - Credentials: cd-postgres-main"
}

# Show current memory stats
show_memory_stats() {
    log_info "Current memory statistics:"

    ssh -i "$SSH_KEY" ubuntu@$EC2_HOST << 'EOF'
docker exec cd-service-db psql -U postgres -d cd_automation_db -c "
SELECT * FROM chat_memory_stats;
"
EOF
}

# Main deployment flow
main() {
    echo "============================================"
    echo "Phase 4: Memory & Context Deployment"
    echo "============================================"
    echo ""

    preflight_checks
    check_postgres

    if check_schema_exists; then
        deploy_schema
        validate_deployment
        test_auto_pruning
    fi

    check_workflow_config
    show_memory_stats

    echo ""
    log_info "Deployment complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Review n8n workflow configuration (see warnings above)"
    echo "  2. Run testing suite: ./test.sh"
    echo "  3. Monitor n8n logs: ssh ubuntu@$EC2_HOST 'docker logs -f n8n'"
    echo ""
}

# Run main function
main "$@"
