# Error Handler Deployment Steps

## Prerequisites
- n8n instance accessible at https://cyber-squire.tigouetheory.com
- Telegram bot token (from credentials_vault.json or COREDIRECTIVE_ENGINE/.env)
- Telegram chat ID: 7868965034

## Step 1: Create n8n Variable

1. Access n8n UI: https://cyber-squire.tigouetheory.com
2. Navigate to: Settings → Variables → Add Variable
3. Configure:
   - **Key**: TELEGRAM_CHAT_ID
   - **Value**: 7868965034
   - **Type**: String
4. Click "Save"

## Step 2: Create Telegram Credential

1. Navigate to: Settings → Credentials → Add Credential
2. Select: "Telegram API"
3. Configure:
   - **Credential Name**: Telegram Bot
   - **Access Token**: [Use token from credentials vault]
   - **Base URL**: https://api.telegram.org (default)
4. Click "Save"
5. Note the credential ID (should be "telegram-bot-main")

## Step 3: Import Error Handler Workflow

Option A - Via n8n UI:
1. Navigate to: Workflows → Add Workflow → Import from File
2. Select: `/tmp/workflow_error_handler.json` (already copied to server)
3. Click Import

Option B - Via SSH and Docker cp:
```bash
ssh -i ~/cyber-squire-ops/cyber-squire-ops.pem ec2-user@54.234.155.244
docker cp /tmp/workflow_error_handler.json cd-service-n8n:/tmp/
# Then import via UI
```

## Step 4: Activate Error Handler

1. Open the imported workflow: "System: Error Handler"
2. Verify the credential reference in "Send Alert" node
3. Click "Activate" toggle in top-right
4. Navigate to: Settings → Workflow Settings
5. Set "Error Workflow": System: Error Handler
6. Save settings

## Step 5: Test Error Handler

Create a test workflow:
```json
{
  "name": "Test Error Handler",
  "nodes": [
    {
      "parameters": {},
      "name": "Manual Trigger",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [240, 300]
    },
    {
      "parameters": {
        "jsCode": "throw new Error('Test error for global error handler');"
      },
      "name": "Generate Error",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [460, 300]
    }
  ],
  "connections": {
    "Manual Trigger": {
      "main": [[{"node": "Generate Error", "type": "main", "index": 0}]]
    }
  }
}
```

Execute and verify Telegram alert is received.

## Verification Checklist

- [ ] n8n variable TELEGRAM_CHAT_ID created with value 7868965034
- [ ] Telegram credential created with ID "telegram-bot-main"
- [ ] Error handler workflow imported and visible in workflow list
- [ ] Error handler workflow activated (toggle is ON)
- [ ] Global error workflow set in Settings
- [ ] Test error triggers Telegram notification
- [ ] Notification includes: workflow name, error message, node name, execution ID

## Troubleshooting

**No Telegram messages received:**
- Verify bot token is correct
- Check chat ID is 7868965034
- Ensure bot has been started with /start command in Telegram
- Check n8n logs: `docker logs cd-service-n8n --tail 100`

**Credential not found error:**
- Ensure credential ID matches "telegram-bot-main"
- Recreate credential with exact name "Telegram Bot"

**Workflow not triggering:**
- Verify error workflow is set in global settings
- Check workflow is activated
- Ensure other workflows are triggering errors
