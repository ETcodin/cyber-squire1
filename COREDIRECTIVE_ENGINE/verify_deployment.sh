#!/bin/bash
# CoreDirective CNS Deployment Verification Script
# Checks all components are properly configured and running

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   CoreDirective CNS Deployment Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0

# Function to check status
check_status() {
    local name=$1
    local command=$2
    
    echo -n "Checking ${name}... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((CHECKS_FAILED++))
        return 1
    fi
}

# Check Docker services
echo -e "${YELLOW}=== Docker Services ===${NC}"
check_status "Docker daemon" "docker info"
check_status "PostgreSQL container" "docker ps | grep cd-service-db"
check_status "n8n container" "docker ps | grep cd-service-n8n"
check_status "Ollama container" "docker ps | grep cd-service-ollama"
check_status "Cloudflare tunnel" "docker ps | grep tunnel-cyber-squire"
echo ""

# Check service health
echo -e "${YELLOW}=== Service Health ===${NC}"
check_status "PostgreSQL ready" "docker exec cd-service-db pg_isready -U \${CD_DB_USER:-coredirective}"
check_status "n8n healthcheck" "curl -sf http://localhost:5678/healthz"
check_status "Ollama API" "curl -sf http://localhost:11434/api/tags"
echo ""

# Check files exist
echo -e "${YELLOW}=== Configuration Files ===${NC}"
check_status "docker-compose.yaml" "test -f docker-compose.yaml"
check_status "credentials_vault.json" "test -f credentials_vault.json"
check_status "inject_credentials.sh" "test -x inject_credentials.sh"
check_status "deploy_workflows.sh" "test -x deploy_workflows.sh"
echo ""

# Check workflow files
echo -e "${YELLOW}=== Workflow Files ===${NC}"
check_status "API Health Check workflow" "test -f workflow_api_healthcheck.json"
check_status "Moltbot Generator workflow" "test -f workflow_moltbot_generator.json"
check_status "Drive Watcher workflow" "test -f workflow_gdrive_watcher.json"
check_status "Operation Nuclear workflow" "test -f workflow_operation_nuclear.json"
check_status "YouTube Factory workflow" "test -f workflow_youtube_factory.json"
check_status "Gumroad Solvency workflow" "test -f workflow_gumroad_solvency.json"
check_status "Task Manager workflow" "test -f workflow_notion_task_manager.json"
check_status "AI Router workflow" "test -f workflow_ai_router.json"
echo ""

# Check volumes
echo -e "${YELLOW}=== Persistent Volumes ===${NC}"
check_status "PostgreSQL volume" "docker volume inspect coredirective_engine_cd-vol-postgres"
check_status "n8n volume" "docker volume inspect coredirective_engine_cd-vol-n8n"
check_status "Ollama volume" "docker volume inspect coredirective_engine_cd-vol-ollama"
echo ""

# Check network
echo -e "${YELLOW}=== Docker Network ===${NC}"
check_status "cd-net bridge network" "docker network inspect cd-net"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Passed: ${CHECKS_PASSED}${NC}"
echo -e "${RED}Failed: ${CHECKS_FAILED}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Your CNS is ready.${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Run: ./inject_credentials.sh"
    echo "2. Run: ./deploy_workflows.sh"
    echo "3. Complete Google OAuth in n8n GUI"
    echo "4. Activate workflows in n8n"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Review errors above.${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "• If services aren't running: docker compose up -d"
    echo "• If files are missing: Check you're in COREDIRECTIVE_ENGINE directory"
    echo "• If volumes missing: They'll be created on first 'docker compose up'"
    echo ""
    exit 1
fi
