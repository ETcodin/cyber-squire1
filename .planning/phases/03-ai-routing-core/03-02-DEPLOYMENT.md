# Phase 03-02 Tool Integration Deployment

## Overview
This guide explains how to connect tool workflows to the Supervisor Agent in n8n.

## Prerequisites
- n8n accessible at https://cyber-squire.tigouetheory.com
- workflow_supervisor_agent.json updated with tool nodes
- workflow_tool_system_status.json ready for import

## Deployment Steps

### 1. Import Tool Workflows
1. Open n8n web interface
2. Navigate to Workflows > Import from File
3. Import in order:
   - `workflow_tool_system_status.json` → Note the workflow ID
   - `workflow_tool_create_task.json` (if ready)
   - `workflow_tool_security_scan.json` (if ready)
4. Activate each imported workflow

### 2. Update Supervisor Agent with Workflow IDs
1. Open `workflow_supervisor_agent.json` in text editor
2. Find tool node: `"id": "tool-system-status"`
3. Replace placeholder workflow ID:
   ```json
   "workflowId": {
     "value": "ACTUAL_WORKFLOW_ID_FROM_N8N",
     "mode": "id"
   }
   ```
4. Repeat for other tools (ADHD Commander, Finance Manager if IDs changed)

### 3. Re-import Supervisor Agent
1. In n8n, update existing Supervisor Agent workflow (or delete and re-import)
2. Verify all tool connections appear in the UI:
   - Look for connected nodes with tool icons
   - Check AI Agent node shows all tools in sidebar
3. Activate workflow

### 4. Verification
Send test message via Telegram:
- "Check system health" → Should trigger System Status tool
- Check n8n execution history for successful tool call
- Verify ROUTING_DECISION log entry appears

## Troubleshooting

**Tool not appearing in AI Agent:**
- Verify workflow ID is correct
- Check ai_tool connection exists in JSON
- Restart n8n if cached

**Tool execution fails:**
- Check tool workflow is activated
- Verify Tool Input/Output nodes are connected
- Review tool workflow execution logs

**System Status returns "Docker not available":**
- Ensure executeCommand node has correct permissions
- Check Docker service is running on EC2 instance
- Verify n8n container has access to Docker socket

## Current Tool Status
- ✅ System Status: Ready for integration (Phase 3)
- ⏳ ADHD Commander: Already integrated (verify ID)
- ⏳ Finance Manager: Already integrated (verify ID)
- 🔜 Create Task: Pending Phase 9 (Core Tools)
- 🔜 Security Scan: Pending Phase 10 (Extended Tools)

## Tool Schema Patterns

All tool descriptions follow this pattern:

```
WHEN to call → Examples → WHAT it returns
```

Example:
```
"Call this tool when [TRIGGER_CONDITION]. Use for [USE_CASES]. Examples: [NATURAL_LANGUAGE_QUERIES]. Returns [OUTPUT_FORMAT]."
```

This pattern helps the AI agent make accurate routing decisions based on user intent.

## Next Steps
After successful deployment:
1. Monitor Telegram interactions for tool routing accuracy
2. Check n8n logs for ROUTING_DECISION entries
3. Adjust tool descriptions if routing is inaccurate
4. Proceed to Phase 03-03 (Testing & Validation)

## Reference
- Supervisor Agent System Prompt: Lines 133-134 in workflow_supervisor_agent.json
- Tool routing logic: Defined in AVAILABLE TOOLS section
- Chat memory configuration: 13-message window (line 116)
