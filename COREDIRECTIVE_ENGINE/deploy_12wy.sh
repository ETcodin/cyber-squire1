#!/bin/bash
# 12WY Operating System Deployment Script
# Deploys Commander and War Room workflows to nuclear-engine

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  12-WEEK YEAR OS DEPLOYMENT${NC}"
echo -e "${GREEN}========================================${NC}"

# Configuration
SSH_HOST="${SSH_HOST:-nuclear-engine}"
REMOTE_DIR="/home/ec2-user/COREDIRECTIVE_ENGINE"
N8N_CONTAINER="cd-service-n8n"

# Verify SSH connection
echo -e "\n${YELLOW}[1/5] Verifying SSH connection...${NC}"
if ! ssh -o ConnectTimeout=10 "$SSH_HOST" 'echo "Connected"' 2>/dev/null; then
    echo -e "${RED}ERROR: Cannot connect to $SSH_HOST${NC}"
    echo "Ensure ~/.ssh/config contains the nuclear-engine block"
    exit 1
fi
echo -e "${GREEN}SSH connection verified${NC}"

# Transfer workflow files
echo -e "\n${YELLOW}[2/5] Transferring 12WY workflow files...${NC}"
scp -q workflow_12wy_commander.json "$SSH_HOST:$REMOTE_DIR/"
scp -q workflow_12wy_warroom.json "$SSH_HOST:$REMOTE_DIR/"
scp -q sql/init_nuclear_log.sql "$SSH_HOST:$REMOTE_DIR/sql/"
scp -q .env.12wy "$SSH_HOST:$REMOTE_DIR/"
echo -e "${GREEN}Files transferred${NC}"

# Initialize database schema
echo -e "\n${YELLOW}[3/5] Initializing nuclear_log database schema...${NC}"
ssh "$SSH_HOST" "docker exec -i cd-service-db psql -U \${CD_DB_USER:-cduser} -d \${CD_DB_NAME:-coredirective} < $REMOTE_DIR/sql/init_nuclear_log.sql" 2>/dev/null || {
    echo -e "${YELLOW}WARNING: Schema may already exist or DB credentials differ${NC}"
}
echo -e "${GREEN}Database schema ready${NC}"

# Import workflows to n8n
echo -e "\n${YELLOW}[4/5] Importing workflows to n8n...${NC}"
for workflow in workflow_12wy_commander.json workflow_12wy_warroom.json; do
    echo "  Importing $workflow..."
    ssh "$SSH_HOST" "docker exec -i $N8N_CONTAINER n8n import:workflow --separate --input=$REMOTE_DIR/$workflow" 2>/dev/null || {
        echo -e "${YELLOW}  Manual import required for $workflow${NC}"
    }
done
echo -e "${GREEN}Workflows imported (activate manually in n8n UI)${NC}"

# Verify services
echo -e "\n${YELLOW}[5/5] Verifying services...${NC}"
ssh "$SSH_HOST" "docker ps --format '{{.Names}}: {{.Status}}' | grep -E 'cd-service|tunnel'" || true

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  DEPLOYMENT COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. SSH: ssh nuclear-engine"
echo "  2. Add .env.12wy values to your n8n environment"
echo "  3. Configure n8n credentials:"
echo "     - Notion API (notion-cred)"
echo "     - Telegram Bot (telegram-bot-main)"
echo "     - Google OAuth (google-oauth-cred)"
echo "     - PostgreSQL (cd-postgres-main)"
echo "  4. Activate workflows in n8n UI"
echo "  5. Test: Send /focus to your Telegram bot"
echo ""
echo -e "${YELLOW}CRITICAL: Ensure Telegram bot token is configured!${NC}"
echo "  Configure \$TELEGRAM_BOT_TOKEN in n8n credentials"
echo "  Previous token was exposed and must be rotated"
