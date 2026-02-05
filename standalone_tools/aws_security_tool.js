/**
 * AWS Security Hub Scraper - Standalone Tool
 * Phase 9: Core Tools (Cyber-Squire Telegram Router)
 *
 * Purpose: Fetch AWS Security Hub findings and format them for ADHD-friendly
 * consumption via Telegram/webhook integration.
 *
 * Environment Variables Required:
 *   CD_AWS_REGION          - AWS region (e.g., us-east-1)
 *   CD_AWS_ACCESS_KEY_ID   - AWS access key
 *   CD_AWS_SECRET_ACCESS_KEY - AWS secret key
 *
 * Usage:
 *   node aws_security_tool.js [--critical-only] [--limit=N]
 *
 * Output: JSON summary of security findings formatted per Phase 7 specs
 */

const {
  SecurityHubClient,
  GetFindingsCommand,
  DescribeHubCommand,
} = require('@aws-sdk/client-securityhub');

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
  region: process.env.CD_AWS_REGION || 'us-east-1',
  maxFindings: parseInt(process.env.CD_MAX_FINDINGS || '100', 10),
  severityThreshold: 70, // CRITICAL=90+, HIGH=70-89, MEDIUM=40-69, LOW=1-39
  adhdBulletLimit: 3,   // Phase 7: Max 3 bullets per list
};

// Severity mapping (AWS Security Hub normalized severity)
const SEVERITY_MAP = {
  CRITICAL: { min: 90, emoji: '🔴', weight: 4 },
  HIGH: { min: 70, emoji: '🟠', weight: 3 },
  MEDIUM: { min: 40, emoji: '🟡', weight: 2 },
  LOW: { min: 1, emoji: '🟢', weight: 1 },
  INFORMATIONAL: { min: 0, emoji: '⚪', weight: 0 },
};

// ============================================================================
// AWS SECURITY HUB CLIENT
// ============================================================================

function createSecurityHubClient() {
  const credentials = {
    accessKeyId: process.env.CD_AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.CD_AWS_SECRET_ACCESS_KEY,
  };

  // Validate credentials exist
  if (!credentials.accessKeyId || !credentials.secretAccessKey) {
    throw new Error(
      'Missing AWS credentials. Set CD_AWS_ACCESS_KEY_ID and CD_AWS_SECRET_ACCESS_KEY'
    );
  }

  return new SecurityHubClient({
    region: CONFIG.region,
    credentials,
  });
}

// ============================================================================
// SECURITY HUB OPERATIONS
// ============================================================================

/**
 * Check if Security Hub is enabled in the account
 */
async function checkSecurityHubStatus(client) {
  try {
    const response = await client.send(new DescribeHubCommand({}));
    return {
      enabled: true,
      hubArn: response.HubArn,
      subscribedAt: response.SubscribedAt,
    };
  } catch (error) {
    if (error.name === 'InvalidAccessException') {
      return { enabled: false, error: 'Security Hub not enabled in this region' };
    }
    throw error;
  }
}

/**
 * Fetch findings from Security Hub with severity filter
 */
async function fetchFindings(client, options = {}) {
  const { criticalOnly = false, limit = CONFIG.maxFindings } = options;

  const filters = {
    // Only active findings (not archived/resolved)
    RecordState: [{ Value: 'ACTIVE', Comparison: 'EQUALS' }],
    WorkflowStatus: [{ Value: 'NEW', Comparison: 'EQUALS' }],
  };

  // Filter by severity if critical-only mode
  if (criticalOnly) {
    filters.SeverityLabel = [
      { Value: 'CRITICAL', Comparison: 'EQUALS' },
      { Value: 'HIGH', Comparison: 'EQUALS' },
    ];
  }

  const command = new GetFindingsCommand({
    Filters: filters,
    MaxResults: Math.min(limit, 100), // AWS limit is 100 per request
    SortCriteria: [
      { Field: 'SeverityNormalized', SortOrder: 'desc' },
      { Field: 'UpdatedAt', SortOrder: 'desc' },
    ],
  });

  const response = await client.send(command);
  return response.Findings || [];
}

// ============================================================================
// DATA PROCESSING
// ============================================================================

/**
 * Categorize and prioritize findings by severity
 */
function categorizeFindings(findings) {
  const categories = {
    CRITICAL: [],
    HIGH: [],
    MEDIUM: [],
    LOW: [],
    INFORMATIONAL: [],
  };

  findings.forEach((finding) => {
    const severity = finding.Severity?.Label || 'INFORMATIONAL';
    if (categories[severity]) {
      categories[severity].push(parseFinding(finding));
    }
  });

  return categories;
}

/**
 * Parse a single finding into simplified structure
 */
function parseFinding(finding) {
  return {
    id: finding.Id,
    title: finding.Title,
    description: truncateText(finding.Description, 200),
    severity: finding.Severity?.Label || 'UNKNOWN',
    severityScore: finding.Severity?.Normalized || 0,
    resource: extractResourceInfo(finding.Resources),
    source: finding.ProductName || 'Unknown',
    createdAt: finding.CreatedAt,
    updatedAt: finding.UpdatedAt,
    compliance: finding.Compliance?.Status,
    remediation: extractRemediation(finding.Remediation),
  };
}

/**
 * Extract resource information from finding
 */
function extractResourceInfo(resources) {
  if (!resources || resources.length === 0) return 'Unknown resource';

  const resource = resources[0];
  return {
    type: resource.Type,
    id: resource.Id,
    region: resource.Region,
    // Truncate for ADHD-friendly display
    display: truncateText(`${resource.Type}: ${resource.Id}`, 60),
  };
}

/**
 * Extract remediation recommendation
 */
function extractRemediation(remediation) {
  if (!remediation) return null;

  return {
    text: remediation.Recommendation?.Text,
    url: remediation.Recommendation?.Url,
  };
}

// ============================================================================
// ADHD-FRIENDLY FORMATTING (Phase 7 Compliance)
// ============================================================================

/**
 * Format findings for ADHD-friendly output
 * - Bold keywords
 * - Max 3 bullets per severity level
 * - Clear "Next step" action
 */
function formatForADHD(categorized, totalCount) {
  const output = {
    tldr: generateTLDR(categorized, totalCount),
    summary: {
      total: totalCount,
      critical: categorized.CRITICAL.length,
      high: categorized.HIGH.length,
      medium: categorized.MEDIUM.length,
      low: categorized.LOW.length,
    },
    topFindings: extractTopFindings(categorized),
    nextStep: generateNextStep(categorized),
    formatted: {
      markdown: formatAsMarkdown(categorized, totalCount),
      telegram: formatForTelegram(categorized, totalCount),
    },
  };

  return output;
}

/**
 * Generate TL;DR summary (Phase 7: <100 chars)
 */
function generateTLDR(categorized, totalCount) {
  const critical = categorized.CRITICAL.length;
  const high = categorized.HIGH.length;

  if (critical > 0) {
    return `🔴 ${critical} CRITICAL + ${high} HIGH severity findings need attention`;
  } else if (high > 0) {
    return `🟠 ${high} HIGH severity findings found, no criticals`;
  } else if (totalCount > 0) {
    return `🟢 ${totalCount} low/medium findings, no urgent issues`;
  }
  return '✅ No active security findings';
}

/**
 * Extract top findings (max 3 per Phase 7 rule)
 */
function extractTopFindings(categorized) {
  const top = [];

  // Prioritize CRITICAL, then HIGH
  ['CRITICAL', 'HIGH', 'MEDIUM'].forEach((severity) => {
    const findings = categorized[severity];
    const severityConfig = SEVERITY_MAP[severity];

    findings.slice(0, CONFIG.adhdBulletLimit).forEach((finding) => {
      top.push({
        emoji: severityConfig.emoji,
        severity: severity,
        title: boldKeywords(finding.title),
        resource: finding.resource.display,
        action: finding.remediation?.text || 'Review and remediate',
      });
    });
  });

  // Limit total to 3 most critical
  return top.slice(0, CONFIG.adhdBulletLimit);
}

/**
 * Generate clear next step (Phase 7 requirement)
 */
function generateNextStep(categorized) {
  const critical = categorized.CRITICAL.length;
  const high = categorized.HIGH.length;

  if (critical > 0) {
    const first = categorized.CRITICAL[0];
    return `Address CRITICAL: ${truncateText(first.title, 50)}`;
  } else if (high > 0) {
    const first = categorized.HIGH[0];
    return `Review HIGH: ${truncateText(first.title, 50)}`;
  }
  return 'Continue monitoring, no urgent action required';
}

/**
 * Bold important keywords for scannability
 */
function boldKeywords(text) {
  const keywords = [
    'critical', 'high', 'exposed', 'public', 'unencrypted',
    'vulnerable', 'misconfigured', 'unrestricted', 'root',
    'admin', 'password', 'secret', 'key', 'access', 'open',
  ];

  let result = text;
  keywords.forEach((keyword) => {
    const regex = new RegExp(`\\b(${keyword})\\b`, 'gi');
    result = result.replace(regex, '**$1**');
  });
  return result;
}

/**
 * Format as Markdown (for logging/display)
 */
function formatAsMarkdown(categorized, totalCount) {
  const lines = [];

  lines.push('## AWS Security Hub Report');
  lines.push('');
  lines.push(`**TL;DR:** ${generateTLDR(categorized, totalCount)}`);
  lines.push('');

  // Summary counts with indicators
  lines.push('### Summary');
  lines.push(`- 🔴 **CRITICAL:** ${categorized.CRITICAL.length}`);
  lines.push(`- 🟠 **HIGH:** ${categorized.HIGH.length}`);
  lines.push(`- 🟡 **MEDIUM:** ${categorized.MEDIUM.length}`);

  // Top findings (max 3)
  if (categorized.CRITICAL.length + categorized.HIGH.length > 0) {
    lines.push('');
    lines.push('### Top Priority Findings');

    const topFindings = extractTopFindings(categorized);
    topFindings.forEach((f) => {
      lines.push(`- ${f.emoji} ${f.title}`);
    });

    const remaining = totalCount - topFindings.length;
    if (remaining > 0) {
      lines.push(`... and ${remaining} more`);
    }
  }

  lines.push('');
  lines.push(`**Next step:** ${generateNextStep(categorized)}`);

  return lines.join('\n');
}

/**
 * Format for Telegram HTML (Phase 7 compliant)
 */
function formatForTelegram(categorized, totalCount) {
  const lines = [];

  lines.push('<b>AWS Security Hub</b>');
  lines.push('');
  lines.push(`<b>TL;DR:</b> ${generateTLDR(categorized, totalCount)}`);
  lines.push('');

  // Severity summary
  const summaryParts = [];
  if (categorized.CRITICAL.length > 0) {
    summaryParts.push(`🔴 ${categorized.CRITICAL.length} Critical`);
  }
  if (categorized.HIGH.length > 0) {
    summaryParts.push(`🟠 ${categorized.HIGH.length} High`);
  }
  if (categorized.MEDIUM.length > 0) {
    summaryParts.push(`🟡 ${categorized.MEDIUM.length} Medium`);
  }

  if (summaryParts.length > 0) {
    lines.push(summaryParts.slice(0, 3).join(' | '));
    lines.push('');
  }

  // Top findings (max 3)
  const topFindings = extractTopFindings(categorized);
  if (topFindings.length > 0) {
    lines.push('<b>Top Issues:</b>');
    topFindings.forEach((f) => {
      // Convert markdown bold to HTML
      const title = f.title.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');
      lines.push(`${f.emoji} ${title}`);
    });
  }

  lines.push('');
  lines.push(`<b>Next step:</b> ${generateNextStep(categorized)}`);

  return lines.join('\n');
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function truncateText(text, maxLength) {
  if (!text) return '';
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength - 3) + '...';
}

function formatTimestamp(isoString) {
  if (!isoString) return 'Unknown';
  const date = new Date(isoString);
  return date.toISOString().split('T')[0]; // YYYY-MM-DD
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

async function scrapeSecurityHub(options = {}) {
  const client = createSecurityHubClient();

  // Check Security Hub status
  const status = await checkSecurityHubStatus(client);
  if (!status.enabled) {
    return {
      success: false,
      error: status.error,
      tldr: '❌ Security Hub not enabled in this region',
    };
  }

  // Fetch findings
  const findings = await fetchFindings(client, options);

  // Categorize by severity
  const categorized = categorizeFindings(findings);

  // Format for ADHD-friendly output
  const output = formatForADHD(categorized, findings.length);

  return {
    success: true,
    timestamp: new Date().toISOString(),
    region: CONFIG.region,
    ...output,
    // Include raw data for downstream processing
    raw: {
      findings: findings.map(parseFinding),
      hubArn: status.hubArn,
    },
  };
}

// CLI execution
if (require.main === module) {
  const args = process.argv.slice(2);
  const criticalOnly = args.includes('--critical-only');
  const limitArg = args.find((a) => a.startsWith('--limit='));
  const limit = limitArg ? parseInt(limitArg.split('=')[1], 10) : undefined;

  console.error(`[AWS Security Hub Scraper]`);
  console.error(`Region: ${CONFIG.region}`);
  console.error(`Mode: ${criticalOnly ? 'Critical/High only' : 'All severities'}`);
  console.error('');

  scrapeSecurityHub({ criticalOnly, limit })
    .then((result) => {
      // Output JSON to stdout for webhook consumption
      console.log(JSON.stringify(result, null, 2));

      // Also print formatted version to stderr for human review
      if (result.success) {
        console.error('---');
        console.error(result.formatted.markdown);
      }
    })
    .catch((error) => {
      console.error(`Error: ${error.message}`);
      console.log(JSON.stringify({
        success: false,
        error: error.message,
        tldr: `❌ Security Hub scan failed: ${error.message}`,
      }));
      process.exit(1);
    });
}

// Export for use as module (webhook integration)
module.exports = {
  scrapeSecurityHub,
  checkSecurityHubStatus,
  fetchFindings,
  categorizeFindings,
  formatForADHD,
  CONFIG,
};
