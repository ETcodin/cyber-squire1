/**
 * Generic Webhook Handler for Standalone Tools
 *
 * This module provides a webhook endpoint that can be called by n8n
 * or other automation systems to invoke standalone tools.
 *
 * Usage with n8n HTTP Request node:
 *   POST /webhook/tool
 *   Body: { "tool": "security_scan", "options": { "criticalOnly": true } }
 *
 * For local testing:
 *   node webhook_handler.js
 *   curl -X POST http://localhost:3000/webhook/tool \
 *     -H "Content-Type: application/json" \
 *     -d '{"tool": "security_scan"}'
 */

const http = require('http');
const tools = require('./index');

const PORT = process.env.WEBHOOK_PORT || 3000;

// Simple HTTP server for webhook
const server = http.createServer(async (req, res) => {
  // CORS headers for n8n integration
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Health check endpoint
  if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
    return;
  }

  // Tool execution endpoint
  if (req.url === '/webhook/tool' && req.method === 'POST') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', async () => {
      try {
        const payload = JSON.parse(body);
        const { tool, options = {} } = payload;

        if (!tool) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            success: false,
            error: 'Missing "tool" in request body',
            tldr: 'Specify which tool to run',
          }));
          return;
        }

        console.log(`[${new Date().toISOString()}] Executing tool: ${tool}`);

        const result = await tools.handleWebhook(tool, options);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
      } catch (error) {
        console.error(`Error: ${error.message}`);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: false,
          error: error.message,
          tldr: `Tool execution failed: ${error.message.substring(0, 50)}`,
        }));
      }
    });
    return;
  }

  // Available tools listing
  if (req.url === '/tools' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      available: [
        // Phase 9
        {
          name: 'security_scan',
          alias: 'aws_security',
          phase: 9,
          description: 'Scan AWS Security Hub for findings',
          options: {
            criticalOnly: 'boolean - Only return CRITICAL/HIGH findings',
            limit: 'number - Max findings to return (default: 100)',
          },
        },
        // Phase 10: Finance
        {
          name: 'finance_log',
          phase: 10,
          description: 'Log a transaction',
          options: {
            amount: 'number - Transaction amount (required)',
            category: 'string - Category (groceries, utilities, etc.)',
            note: 'string - Optional description',
          },
        },
        {
          name: 'finance_status',
          alias: 'debt_status',
          phase: 10,
          description: 'Get debt burn-down status',
          options: {},
        },
        {
          name: 'finance_history',
          phase: 10,
          description: 'Get transaction history',
          options: {
            days: 'number - Days to look back (default: 30)',
            category: 'string - Filter by category',
          },
        },
        // Phase 10: Scanner
        {
          name: 'scan_validate',
          phase: 10,
          description: 'Validate target and get confirmation token',
          options: {
            target: 'string - Domain or IP to scan (required)',
          },
        },
        {
          name: 'scan_nmap',
          phase: 10,
          description: 'Run Nmap port scan (requires token)',
          options: {
            target: 'string - Domain or IP (required)',
            token: 'string - Confirmation token from validate (required)',
          },
        },
        {
          name: 'scan_nuclei',
          phase: 10,
          description: 'Run Nuclei vulnerability scan (requires token)',
          options: {
            target: 'string - Domain or IP (required)',
            token: 'string - Confirmation token from validate (required)',
          },
        },
      ],
    }));
    return;
  }

  // 404 for unknown routes
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    success: false,
    error: 'Not found',
    endpoints: ['/webhook/tool', '/health', '/tools'],
  }));
});

// Start server if run directly
if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`Standalone Tools Webhook Server`);
    console.log(`================================`);
    console.log(`Port: ${PORT}`);
    console.log(`Endpoints:`);
    console.log(`  POST /webhook/tool - Execute a tool`);
    console.log(`  GET  /health       - Health check`);
    console.log(`  GET  /tools        - List available tools`);
    console.log(`================================`);
  });
}

module.exports = server;
