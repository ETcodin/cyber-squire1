/**
 * Standalone Tools Index
 * Entry point for all Phase 7-10 tools
 *
 * Usage:
 *   const tools = require('./standalone_tools');
 *   const result = await tools.security.scrape({ criticalOnly: true });
 */

// Load environment from .env if present
try {
  require('dotenv').config({ path: __dirname + '/.env' });
} catch (e) {
  // dotenv optional in production
}

// Phase 9: Core Tools
const awsSecurityTool = require('./aws_security_tool');

// Phase 10: Extended Tools
const financeManager = require('./finance_manager');
const securityScanner = require('./security_scanner');

// Export organized by category
module.exports = {
  // AWS Security Hub (Phase 9)
  security: {
    scrape: awsSecurityTool.scrapeSecurityHub,
    checkHub: awsSecurityTool.checkSecurityHubStatus,
    fetchFindings: awsSecurityTool.fetchFindings,
    categorize: awsSecurityTool.categorizeFindings,
    format: awsSecurityTool.formatForADHD,
  },

  // Finance Manager (Phase 10 - TOOL-03)
  finance: {
    log: financeManager.logTransaction,
    status: financeManager.getDebtStatus,
    history: financeManager.getHistory,
    burnRate: financeManager.calculateMonthlyBurnRate,
  },

  // Security Scanner (Phase 10 - TOOL-04)
  scanner: {
    validate: securityScanner.validateTarget,
    nmap: securityScanner.runNmapScan,
    nuclei: securityScanner.runNucleiScan,
    isWhitelisted: securityScanner.isWhitelisted,
  },

  // Utility for webhook handlers
  handleWebhook: async (toolName, options = {}) => {
    switch (toolName) {
      // Phase 9: AWS Security Hub
      case 'security_scan':
      case 'aws_security':
        return await awsSecurityTool.scrapeSecurityHub(options);

      // Phase 10: Finance Manager
      case 'finance_log':
        return financeManager.logTransaction(options);
      case 'finance_status':
      case 'debt_status':
        return financeManager.getDebtStatus();
      case 'finance_history':
        return financeManager.getHistory(options);

      // Phase 10: Security Scanner
      case 'scan_validate':
        return securityScanner.validateTarget(options.target);
      case 'scan_nmap':
        return await securityScanner.runNmapScan(options.target, options.token);
      case 'scan_nuclei':
        return await securityScanner.runNucleiScan(options.target, options.token);

      default:
        return {
          success: false,
          error: `Unknown tool: ${toolName}`,
          tldr: `Tool "${toolName}" not found`,
        };
    }
  },
};
