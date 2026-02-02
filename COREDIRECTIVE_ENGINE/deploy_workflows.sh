#!/bin/bash
# CoreDirective CNS Workflow Deployment Script
# Deploys all automation workflows to n8n via REST API

set -e  # Exit on error

N8N_HOST="${N8N_HOST:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:?ERROR: N8N_API_KEY environment variable required}"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   CoreDirective CNS Workflow Deployment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if n8n is accessible
echo -e "${YELLOW}Checking n8n availability...${NC}"
if ! curl -s -f "${N8N_HOST}/healthz" > /dev/null; then
    echo -e "${RED}❌ ERROR: n8n is not accessible at ${N8N_HOST}${NC}"
    echo -e "${YELLOW}   Start services: docker compose up -d${NC}"
    exit 1
fi
echo -e "${GREEN}✓ n8n is running${NC}"
echo ""

# Array of workflow files
WORKFLOWS=(
    "workflow_api_healthcheck.json:🏥 API Health Check"
    "workflow_moltbot_generator.json:🤖 Moltbot Workflow Generator"
    "workflow_gdrive_watcher.json:📂 Google Drive File Watcher"
    "workflow_operation_nuclear.json:☢️ Operation Nuclear Lead Enrichment"
    "workflow_youtube_factory.json:🎬 YouTube Content Factory"
    "workflow_gumroad_solvency.json:💰 Gumroad Solvency Engine"
    "workflow_notion_task_manager.json:📋 Notion Task Manager"
    "workflow_ai_router.json:🧠 AI Intelligence Router"
)

DEPLOYED=0
FAILED=0

# Deploy each workflow
for WORKFLOW in "${WORKFLOWS[@]}"; do
    FILE=$(echo $WORKFLOW | cut -d: -f1)
    NAME=$(echo $WORKFLOW | cut -d: -f2)

    echo -e "${YELLOW}Deploying: ${NAME}...${NC}"

    if [ ! -f "$FILE" ]; then
        echo -e "${RED}  ❌ File not found: ${FILE}${NC}"
        ((FAILED++))
        continue
    fi

    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${N8N_HOST}/api/v1/workflows" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d @${FILE})

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
        WORKFLOW_ID=$(echo "$BODY" | jq -r '.id' 2>/dev/null || echo "unknown")
        echo -e "${GREEN}  ✓ Success (ID: ${WORKFLOW_ID})${NC}"
        ((DEPLOYED++))
    else
        echo -e "${RED}  ❌ Failed (HTTP ${HTTP_CODE})${NC}"
        if [ ! -z "$BODY" ]; then
            echo -e "${RED}     $(echo $BODY | jq -r '.message' 2>/dev/null || echo $BODY)${NC}"
        fi
        ((FAILED++))
    fi
    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Deployment Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${GREEN}Deployed:${NC} ${DEPLOYED}"
echo -e "  ${RED}Failed:${NC}   ${FAILED}"
echo ""

if [ $DEPLOYED -gt 0 ]; then
    echo -e "${YELLOW}📋 Post-Deployment Steps:${NC}"
    echo ""
    echo -e "  1. Go to ${BLUE}https://n8n.yourdomain.com${NC}"
    echo ""
    echo -e "  2. ${YELLOW}Configure Google OAuth:${NC}"
    echo "     • Open 'Google OAuth CoreDirective' credential"
    echo "     • Click 'Sign in with Google' to authorize"
    echo ""
    echo -e "  3. ${YELLOW}Set Notion Database IDs in workflows:${NC}"
    echo "     • notion_tasks_db (Task Manager workflow)"
    echo "     • notion_leads_db (Operation Nuclear workflow)"
    echo "     • notion_content_db (YouTube Factory workflow)"
    echo "     • notion_media_db (Drive Watcher workflow)"
    echo "     • notion_finance_db (Gumroad Solvency workflow)"
    echo ""
    echo -e "  4. ${YELLOW}Activate workflows:${NC}"
    echo "     • Go to each workflow in n8n"
    echo "     • Click 'Active' toggle to enable"
    echo ""
    echo -e "  5. ${YELLOW}Test webhooks:${NC}"
    echo "     • Moltbot Generator: POST /webhook/moltbot-command"
    echo "     • Operation Nuclear: POST /webhook/lead-intake"
    echo "     • YouTube Factory: POST /webhook/youtube-content-factory"
    echo "     • AI Router: POST /webhook/ai-router"
    echo ""
    echo -e "${GREEN}🚀 Your Cyber-Squire CNS is ready to operate!${NC}"
fi

echo ""
exit 0
