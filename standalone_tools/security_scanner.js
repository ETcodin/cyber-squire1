/**
 * Security Scanner - Standalone Tool
 * Phase 10: Extended Tools (Cyber-Squire Telegram Router)
 *
 * Purpose: Run Nmap/Nuclei scans with target whitelist validation
 * and confirmation flow. Designed for authorized pentesting only.
 *
 * Features:
 *   - Target whitelist validation (safety first)
 *   - Confirmation token generation for destructive scans
 *   - Nmap port scanning
 *   - Nuclei vulnerability scanning
 *   - ADHD-friendly severity-prioritized output
 *
 * Environment Variables:
 *   CD_SCAN_WHITELIST    - Comma-separated allowed targets
 *   CD_SSH_HOST          - EC2 host for remote execution
 *   CD_SSH_USER          - SSH user (default: ec2-user)
 *   CD_SSH_KEY_PATH      - Path to SSH private key
 *   CD_SCAN_TIMEOUT      - Scan timeout in seconds (default: 300)
 *
 * Usage:
 *   node security_scanner.js validate --target=example.com
 *   node security_scanner.js nmap --target=example.com --token=abc123
 *   node security_scanner.js nuclei --target=example.com --token=abc123
 *
 * IMPORTANT: Only use on targets you own or have explicit authorization to scan.
 */

const crypto = require('crypto');
const { execSync, spawn } = require('child_process');

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
  // Whitelist of allowed scan targets (domains/IPs)
  whitelist: (process.env.CD_SCAN_WHITELIST || '').split(',').filter(Boolean),

  // SSH configuration for remote execution
  ssh: {
    host: process.env.CD_SSH_HOST,
    user: process.env.CD_SSH_USER || 'ec2-user',
    keyPath: process.env.CD_SSH_KEY_PATH,
  },

  // Scan settings
  timeout: parseInt(process.env.CD_SCAN_TIMEOUT || '300', 10),
  tokenExpiry: 5 * 60 * 1000, // 5 minutes (Phase 8: button expiry)

  // ADHD formatting
  adhdBulletLimit: 3,
  maxOutputLines: 50,
};

// In-memory token store (use Redis in production)
const pendingScans = new Map();

// Severity mapping for findings
const SEVERITY = {
  critical: { emoji: '🔴', weight: 4 },
  high: { emoji: '🟠', weight: 3 },
  medium: { emoji: '🟡', weight: 2 },
  low: { emoji: '🟢', weight: 1 },
  info: { emoji: '⚪', weight: 0 },
};

// ============================================================================
// WHITELIST VALIDATION
// ============================================================================

/**
 * Check if a target is in the whitelist
 */
function isWhitelisted(target) {
  if (CONFIG.whitelist.length === 0) {
    return { allowed: false, reason: 'No whitelist configured. Set CD_SCAN_WHITELIST.' };
  }

  const normalizedTarget = target.toLowerCase().trim();

  // Check exact match
  if (CONFIG.whitelist.includes(normalizedTarget)) {
    return { allowed: true };
  }

  // Check if target is a subdomain of whitelisted domain
  for (const allowed of CONFIG.whitelist) {
    if (normalizedTarget.endsWith('.' + allowed.toLowerCase())) {
      return { allowed: true };
    }
  }

  return {
    allowed: false,
    reason: `Target "${target}" not in whitelist`,
    whitelist: CONFIG.whitelist,
  };
}

/**
 * Validate target and generate confirmation token
 */
function validateTarget(target) {
  // Basic input sanitization
  if (!target || typeof target !== 'string') {
    return {
      success: false,
      error: 'Invalid target',
      tldr: '❌ Specify a valid target',
    };
  }

  // Remove protocol if present
  const cleanTarget = target.replace(/^https?:\/\//, '').split('/')[0];

  // Validate format (domain or IP)
  const domainRegex = /^[a-zA-Z0-9][a-zA-Z0-9-_.]+[a-zA-Z0-9]$/;
  const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;

  if (!domainRegex.test(cleanTarget) && !ipRegex.test(cleanTarget)) {
    return {
      success: false,
      error: 'Invalid target format',
      tldr: '❌ Target must be a valid domain or IP',
    };
  }

  // Check whitelist
  const whitelistCheck = isWhitelisted(cleanTarget);
  if (!whitelistCheck.allowed) {
    return {
      success: false,
      error: whitelistCheck.reason,
      tldr: `🚫 Target not authorized for scanning`,
      whitelist: whitelistCheck.whitelist,
      formatted: formatWhitelistError(cleanTarget, whitelistCheck),
    };
  }

  // Generate confirmation token
  const token = crypto.randomBytes(8).toString('hex');
  const expiry = Date.now() + CONFIG.tokenExpiry;

  pendingScans.set(token, {
    target: cleanTarget,
    expiry,
    created: new Date().toISOString(),
  });

  // Clean up expired tokens
  cleanupExpiredTokens();

  return {
    success: true,
    target: cleanTarget,
    token,
    expiresIn: '5 minutes',
    tldr: `✅ Target "${cleanTarget}" authorized`,
    formatted: formatConfirmationPrompt(cleanTarget, token),
    // For Telegram inline buttons (Phase 8)
    buttons: [
      { text: '🔍 Run Nmap Scan', callback: `scan_nmap_${token}` },
      { text: '🎯 Run Nuclei Scan', callback: `scan_nuclei_${token}` },
      { text: '❌ Cancel', callback: `scan_cancel_${token}` },
    ],
  };
}

/**
 * Verify a scan token is valid
 */
function verifyToken(token) {
  const scan = pendingScans.get(token);

  if (!scan) {
    return { valid: false, reason: 'Token not found or already used' };
  }

  if (Date.now() > scan.expiry) {
    pendingScans.delete(token);
    return { valid: false, reason: 'Token expired' };
  }

  return { valid: true, target: scan.target };
}

function cleanupExpiredTokens() {
  const now = Date.now();
  for (const [token, scan] of pendingScans) {
    if (now > scan.expiry) {
      pendingScans.delete(token);
    }
  }
}

// ============================================================================
// SCAN EXECUTION
// ============================================================================

/**
 * Run Nmap scan
 */
async function runNmapScan(target, token) {
  // Verify token
  const tokenCheck = verifyToken(token);
  if (!tokenCheck.valid) {
    return {
      success: false,
      error: tokenCheck.reason,
      tldr: `❌ ${tokenCheck.reason}`,
    };
  }

  // Consume token (one-time use)
  pendingScans.delete(token);

  try {
    // Nmap command - quick scan of common ports
    const nmapCmd = `nmap -sV -sC --top-ports 100 -T4 --max-retries 2 ${target}`;

    console.error(`[Nmap] Scanning ${target}...`);
    const startTime = Date.now();

    let output;
    if (CONFIG.ssh.host && CONFIG.ssh.keyPath) {
      // Remote execution via SSH
      output = await executeRemote(nmapCmd);
    } else {
      // Local execution
      output = execSync(nmapCmd, {
        timeout: CONFIG.timeout * 1000,
        encoding: 'utf-8',
      });
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    const parsed = parseNmapOutput(output);

    return {
      success: true,
      target,
      scanType: 'nmap',
      duration: `${duration}s`,
      ...parsed,
      tldr: generateNmapTLDR(parsed),
      formatted: formatNmapResults(target, parsed, duration),
      raw: output.substring(0, 5000), // Truncate for safety
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      tldr: `❌ Nmap scan failed: ${error.message.substring(0, 50)}`,
    };
  }
}

/**
 * Run Nuclei scan
 */
async function runNucleiScan(target, token) {
  // Verify token
  const tokenCheck = verifyToken(token);
  if (!tokenCheck.valid) {
    return {
      success: false,
      error: tokenCheck.reason,
      tldr: `❌ ${tokenCheck.reason}`,
    };
  }

  // Consume token
  pendingScans.delete(token);

  try {
    // Nuclei command - common vulnerabilities
    const nucleiCmd = `nuclei -u https://${target} -severity critical,high,medium -json -silent`;

    console.error(`[Nuclei] Scanning ${target}...`);
    const startTime = Date.now();

    let output;
    if (CONFIG.ssh.host && CONFIG.ssh.keyPath) {
      output = await executeRemote(nucleiCmd);
    } else {
      output = execSync(nucleiCmd, {
        timeout: CONFIG.timeout * 1000,
        encoding: 'utf-8',
      });
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    const parsed = parseNucleiOutput(output);

    return {
      success: true,
      target,
      scanType: 'nuclei',
      duration: `${duration}s`,
      ...parsed,
      tldr: generateNucleiTLDR(parsed),
      formatted: formatNucleiResults(target, parsed, duration),
      raw: output.substring(0, 5000),
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      tldr: `❌ Nuclei scan failed: ${error.message.substring(0, 50)}`,
    };
  }
}

/**
 * Execute command remotely via SSH
 */
function executeRemote(command) {
  const sshCmd = `ssh -i ${CONFIG.ssh.keyPath} -o StrictHostKeyChecking=no ${CONFIG.ssh.user}@${CONFIG.ssh.host} "${command}"`;

  return execSync(sshCmd, {
    timeout: CONFIG.timeout * 1000,
    encoding: 'utf-8',
  });
}

// ============================================================================
// OUTPUT PARSING
// ============================================================================

/**
 * Parse Nmap output into structured data
 */
function parseNmapOutput(output) {
  const lines = output.split('\n');
  const ports = [];
  const services = [];

  // Parse open ports
  const portRegex = /^(\d+)\/(tcp|udp)\s+(\w+)\s+(.*)$/;
  lines.forEach(line => {
    const match = line.match(portRegex);
    if (match) {
      ports.push({
        port: parseInt(match[1]),
        protocol: match[2],
        state: match[3],
        service: match[4].trim(),
      });
    }
  });

  // Categorize findings by risk
  const findings = {
    critical: [],
    high: [],
    medium: [],
    low: [],
    info: [],
  };

  // Risky ports/services
  const riskyPorts = {
    21: 'high',    // FTP
    22: 'medium',  // SSH (info if properly configured)
    23: 'critical', // Telnet
    25: 'medium',  // SMTP
    445: 'high',   // SMB
    3389: 'high',  // RDP
    3306: 'high',  // MySQL
    5432: 'high',  // PostgreSQL
    27017: 'high', // MongoDB
  };

  ports.forEach(p => {
    const severity = riskyPorts[p.port] || 'info';
    findings[severity].push({
      type: 'open_port',
      port: p.port,
      service: p.service,
      message: `Port ${p.port} (${p.service}) is open`,
    });
  });

  return {
    openPorts: ports.length,
    ports,
    findings,
    summary: {
      critical: findings.critical.length,
      high: findings.high.length,
      medium: findings.medium.length,
      low: findings.low.length,
    },
  };
}

/**
 * Parse Nuclei JSON output
 */
function parseNucleiOutput(output) {
  const findings = {
    critical: [],
    high: [],
    medium: [],
    low: [],
    info: [],
  };

  // Parse JSON lines
  const lines = output.split('\n').filter(Boolean);
  lines.forEach(line => {
    try {
      const finding = JSON.parse(line);
      const severity = (finding.info?.severity || 'info').toLowerCase();

      if (findings[severity]) {
        findings[severity].push({
          templateId: finding['template-id'],
          name: finding.info?.name,
          severity,
          matched: finding['matched-at'],
          description: finding.info?.description,
        });
      }
    } catch (e) {
      // Skip non-JSON lines
    }
  });

  return {
    totalFindings: Object.values(findings).flat().length,
    findings,
    summary: {
      critical: findings.critical.length,
      high: findings.high.length,
      medium: findings.medium.length,
      low: findings.low.length,
    },
  };
}

// ============================================================================
// ADHD-FRIENDLY FORMATTING (Phase 7 Compliance)
// ============================================================================

/**
 * Format whitelist error
 */
function formatWhitelistError(target, check) {
  const lines = [
    `**Scan Blocked**`,
    ``,
    `🚫 Target "${target}" is **not authorized**`,
    ``,
    `**Whitelisted targets:**`,
  ];

  (check.whitelist || []).slice(0, CONFIG.adhdBulletLimit).forEach(t => {
    lines.push(`• ${t}`);
  });

  lines.push(``);
  lines.push(`**Next step:** Add target to CD_SCAN_WHITELIST or use an authorized target`);

  return {
    markdown: lines.join('\n'),
    telegram: lines.map(l => l.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>')).join('\n'),
  };
}

/**
 * Format confirmation prompt with buttons
 */
function formatConfirmationPrompt(target, token) {
  const lines = [
    `**Scan Authorization**`,
    ``,
    `✅ Target: **${target}**`,
    `🔑 Token: \`${token}\``,
    `⏱️ Expires in 5 minutes`,
    ``,
    `**Select scan type:**`,
    `• **Nmap** - Port & service discovery`,
    `• **Nuclei** - Vulnerability detection`,
    ``,
    `**Next step:** Click a button or run with --token=${token}`,
  ];

  return {
    markdown: lines.join('\n'),
    telegram: lines.map(l => l.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>').replace(/`(.*?)`/g, '<code>$1</code>')).join('\n'),
  };
}

/**
 * Generate Nmap TL;DR
 */
function generateNmapTLDR(parsed) {
  const { summary, openPorts } = parsed;

  if (summary.critical > 0) {
    return `🔴 ${openPorts} ports open - ${summary.critical} CRITICAL (dangerous services exposed)`;
  } else if (summary.high > 0) {
    return `🟠 ${openPorts} ports open - ${summary.high} HIGH risk services found`;
  } else if (openPorts > 0) {
    return `🟡 ${openPorts} ports open - No critical risks detected`;
  }
  return `✅ No open ports detected`;
}

/**
 * Format Nmap results
 */
function formatNmapResults(target, parsed, duration) {
  const lines = [
    `**Nmap Scan Results**`,
    ``,
    `🎯 Target: **${target}**`,
    `⏱️ Duration: ${duration}`,
    ``,
  ];

  // Summary line
  const { summary, openPorts } = parsed;
  if (summary.critical > 0) {
    lines.push(`🔴 **${summary.critical} CRITICAL** | 🟠 ${summary.high} High | 🟡 ${summary.medium} Medium`);
  } else {
    lines.push(`📊 ${openPorts} open ports found`);
  }

  lines.push(``);

  // Top findings (max 3)
  const allFindings = [
    ...parsed.findings.critical,
    ...parsed.findings.high,
    ...parsed.findings.medium,
  ].slice(0, CONFIG.adhdBulletLimit);

  if (allFindings.length > 0) {
    lines.push(`**Top Findings:**`);
    allFindings.forEach(f => {
      const emoji = SEVERITY[f.type === 'open_port' ? 'medium' : 'info'].emoji;
      lines.push(`• ${emoji} ${f.message}`);
    });

    const remaining = parsed.openPorts - allFindings.length;
    if (remaining > 0) {
      lines.push(`... and ${remaining} more`);
    }
  }

  lines.push(``);
  lines.push(`**Next step:** Review findings and close unnecessary ports`);

  return {
    markdown: lines.join('\n'),
    telegram: lines.map(l => l.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>')).join('\n'),
  };
}

/**
 * Generate Nuclei TL;DR
 */
function generateNucleiTLDR(parsed) {
  const { summary, totalFindings } = parsed;

  if (summary.critical > 0) {
    return `🔴 ${summary.critical} CRITICAL vulnerabilities found!`;
  } else if (summary.high > 0) {
    return `🟠 ${summary.high} HIGH severity vulnerabilities detected`;
  } else if (totalFindings > 0) {
    return `🟡 ${totalFindings} findings (no critical/high)`;
  }
  return `✅ No vulnerabilities detected`;
}

/**
 * Format Nuclei results
 */
function formatNucleiResults(target, parsed, duration) {
  const lines = [
    `**Nuclei Scan Results**`,
    ``,
    `🎯 Target: **${target}**`,
    `⏱️ Duration: ${duration}`,
    ``,
  ];

  const { summary, totalFindings } = parsed;

  // Summary counts
  if (totalFindings > 0) {
    const parts = [];
    if (summary.critical > 0) parts.push(`🔴 **${summary.critical} Critical**`);
    if (summary.high > 0) parts.push(`🟠 ${summary.high} High`);
    if (summary.medium > 0) parts.push(`🟡 ${summary.medium} Medium`);
    lines.push(parts.join(' | '));
    lines.push(``);
  } else {
    lines.push(`✅ No vulnerabilities found`);
    lines.push(``);
  }

  // Top findings (max 3)
  const topFindings = [
    ...parsed.findings.critical,
    ...parsed.findings.high,
    ...parsed.findings.medium,
  ].slice(0, CONFIG.adhdBulletLimit);

  if (topFindings.length > 0) {
    lines.push(`**Top Vulnerabilities:**`);
    topFindings.forEach(f => {
      const emoji = SEVERITY[f.severity]?.emoji || '⚪';
      lines.push(`• ${emoji} **${f.name || f.templateId}**`);
    });

    const remaining = totalFindings - topFindings.length;
    if (remaining > 0) {
      lines.push(`... and ${remaining} more`);
    }
  }

  lines.push(``);
  lines.push(`**Next step:** Prioritize and remediate critical findings`);

  return {
    markdown: lines.join('\n'),
    telegram: lines.map(l => l.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>')).join('\n'),
  };
}

// ============================================================================
// CLI EXECUTION
// ============================================================================

function parseCliArgs(args) {
  const parsed = { command: args[0] };

  args.slice(1).forEach(arg => {
    if (arg.startsWith('--')) {
      const [key, value] = arg.substring(2).split('=');
      parsed[key] = value || true;
    }
  });

  return parsed;
}

async function main() {
  const args = parseCliArgs(process.argv.slice(2));

  if (!args.command) {
    console.log(`Security Scanner - Phase 10 Tool

Usage:
  node security_scanner.js validate --target=example.com
  node security_scanner.js nmap --target=example.com --token=TOKEN
  node security_scanner.js nuclei --target=example.com --token=TOKEN

Environment:
  CD_SCAN_WHITELIST - Comma-separated allowed targets (REQUIRED)
  CD_SSH_HOST       - Remote host for scan execution
  CD_SSH_USER       - SSH user (default: ec2-user)
  CD_SSH_KEY_PATH   - Path to SSH private key
  CD_SCAN_TIMEOUT   - Timeout in seconds (default: 300)

⚠️  Only scan targets you own or have authorization to test.
`);
    return;
  }

  let result;

  switch (args.command) {
    case 'validate':
      result = validateTarget(args.target);
      break;

    case 'nmap':
      if (!args.token) {
        // Auto-validate and generate token
        result = validateTarget(args.target);
        if (result.success) {
          console.error('Token generated. Re-run with --token=' + result.token);
        }
      } else {
        result = await runNmapScan(args.target, args.token);
      }
      break;

    case 'nuclei':
      if (!args.token) {
        result = validateTarget(args.target);
        if (result.success) {
          console.error('Token generated. Re-run with --token=' + result.token);
        }
      } else {
        result = await runNucleiScan(args.target, args.token);
      }
      break;

    default:
      result = {
        success: false,
        error: `Unknown command: ${args.command}`,
        tldr: `❌ Unknown command "${args.command}"`,
      };
  }

  console.log(JSON.stringify(result, null, 2));

  if (result.formatted) {
    console.error('\n---');
    console.error(result.formatted.markdown);
  }
}

if (require.main === module) {
  main().catch(err => {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  });
}

module.exports = {
  validateTarget,
  verifyToken,
  isWhitelisted,
  runNmapScan,
  runNucleiScan,
  parseNmapOutput,
  parseNucleiOutput,
  CONFIG,
};
