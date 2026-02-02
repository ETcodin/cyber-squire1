#!/bin/bash
# CoreDirective Credential Injection Script
# Injects all API credentials into n8n via REST API from credentials_vault.json

N8N_HOST="${N8N_HOST:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:?ERROR: N8N_API_KEY environment variable not set}"
VAULT_FILE="${VAULT_FILE:-credentials_vault.json}"

echo "🔐 CoreDirective Credential Injector"
echo "===================================="
echo ""

# Check if vault file exists
if [ ! -f "$VAULT_FILE" ]; then
    echo "❌ ERROR: $VAULT_FILE not found"
    exit 1
fi

# Check if n8n is accessible
echo "Checking n8n availability..."
if ! curl -s -f "${N8N_HOST}/healthz" > /dev/null; then
    echo "❌ ERROR: n8n is not accessible at ${N8N_HOST}"
    echo "   Make sure Docker services are running: docker compose up -d"
    exit 1
fi

echo "✓ n8n is running"
echo "✓ Found $VAULT_FILE"
echo ""

# Extract and inject each credential from vault
CRED_KEYS=("anthropic" "github" "google_oauth" "gumroad" "notion" "perplexity")

for KEY in "${CRED_KEYS[@]}"; do
    # Extract credential from vault using jq
    CRED_JSON=$(jq -c ".credentials.${KEY}" "$VAULT_FILE")
    CRED_NAME=$(echo "$CRED_JSON" | jq -r '.name')

    echo "Injecting: ${CRED_NAME}..."

    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${N8N_HOST}/api/v1/credentials" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$CRED_JSON")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
        echo "  ✓ Success (HTTP ${HTTP_CODE})"
    else
        echo "  ❌ Failed (HTTP ${HTTP_CODE})"
        echo "  Response: ${BODY}"
    fi
    echo ""
done

echo "===================================="
echo "✓ Credential injection complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Access your n8n instance via Cloudflare Tunnel"
echo "2. Open 'Google OAuth CoreDirective' credential"
echo "3. Click 'Sign in with Google' to complete OAuth flow"
echo "4. Import workflow_api_healthcheck.json for monitoring"
echo ""
