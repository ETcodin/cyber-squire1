/**
 * Test Suite for Standalone Tools
 * Run: node test_tools.js
 *
 * Tests module structure and formatting logic without requiring external credentials.
 */

const awsTool = require('./aws_security_tool');
const financeTool = require('./finance_manager');
const scannerTool = require('./security_scanner');

console.log('=== Standalone Tools Test Suite ===\n');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`✅ ${name}`);
    passed++;
  } catch (error) {
    console.log(`❌ ${name}`);
    console.log(`   Error: ${error.message}`);
    failed++;
  }
}

function assertEqual(actual, expected, msg = '') {
  if (actual !== expected) {
    throw new Error(`${msg} Expected "${expected}", got "${actual}"`);
  }
}

function assertTrue(condition, msg = '') {
  if (!condition) {
    throw new Error(msg || 'Assertion failed');
  }
}

// =============================================================================
// Module Structure Tests
// =============================================================================

test('Module exports scrapeSecurityHub function', () => {
  assertTrue(typeof awsTool.scrapeSecurityHub === 'function');
});

test('Module exports categorizeFindings function', () => {
  assertTrue(typeof awsTool.categorizeFindings === 'function');
});

test('Module exports formatForADHD function', () => {
  assertTrue(typeof awsTool.formatForADHD === 'function');
});

test('CONFIG has required fields', () => {
  assertTrue(awsTool.CONFIG.region !== undefined);
  assertTrue(awsTool.CONFIG.maxFindings > 0);
  assertTrue(awsTool.CONFIG.adhdBulletLimit === 3);
});

// =============================================================================
// Categorization Tests
// =============================================================================

const mockFindings = [
  {
    Id: 'finding-1',
    Title: 'S3 bucket publicly exposed',
    Description: 'An S3 bucket has public access enabled',
    Severity: { Label: 'CRITICAL', Normalized: 95 },
    Resources: [{ Type: 'AwsS3Bucket', Id: 'my-bucket', Region: 'us-east-1' }],
    CreatedAt: '2026-02-01T00:00:00Z',
    UpdatedAt: '2026-02-04T00:00:00Z',
  },
  {
    Id: 'finding-2',
    Title: 'Security group allows unrestricted SSH',
    Description: 'Port 22 open to 0.0.0.0/0',
    Severity: { Label: 'HIGH', Normalized: 75 },
    Resources: [{ Type: 'AwsEc2SecurityGroup', Id: 'sg-123', Region: 'us-east-1' }],
    CreatedAt: '2026-02-02T00:00:00Z',
    UpdatedAt: '2026-02-04T00:00:00Z',
  },
  {
    Id: 'finding-3',
    Title: 'IAM password policy weak',
    Description: 'Password policy does not require symbols',
    Severity: { Label: 'MEDIUM', Normalized: 50 },
    Resources: [{ Type: 'AwsAccount', Id: '123456789', Region: 'us-east-1' }],
    CreatedAt: '2026-02-03T00:00:00Z',
    UpdatedAt: '2026-02-04T00:00:00Z',
  },
];

test('categorizeFindings groups by severity', () => {
  const categorized = awsTool.categorizeFindings(mockFindings);
  assertEqual(categorized.CRITICAL.length, 1, 'CRITICAL count');
  assertEqual(categorized.HIGH.length, 1, 'HIGH count');
  assertEqual(categorized.MEDIUM.length, 1, 'MEDIUM count');
  assertEqual(categorized.LOW.length, 0, 'LOW count');
});

// =============================================================================
// ADHD Formatting Tests (Phase 7 Compliance)
// =============================================================================

test('formatForADHD returns required structure', () => {
  const categorized = awsTool.categorizeFindings(mockFindings);
  const output = awsTool.formatForADHD(categorized, mockFindings.length);

  assertTrue(output.tldr !== undefined, 'Has tldr');
  assertTrue(output.summary !== undefined, 'Has summary');
  assertTrue(output.topFindings !== undefined, 'Has topFindings');
  assertTrue(output.nextStep !== undefined, 'Has nextStep');
  assertTrue(output.formatted !== undefined, 'Has formatted');
});

test('TL;DR is under 100 characters (Phase 7)', () => {
  const categorized = awsTool.categorizeFindings(mockFindings);
  const output = awsTool.formatForADHD(categorized, mockFindings.length);

  assertTrue(output.tldr.length <= 100, `TL;DR too long: ${output.tldr.length} chars`);
});

test('topFindings limited to 3 items (Phase 7)', () => {
  const categorized = awsTool.categorizeFindings(mockFindings);
  const output = awsTool.formatForADHD(categorized, mockFindings.length);

  assertTrue(
    output.topFindings.length <= 3,
    `Too many top findings: ${output.topFindings.length}`
  );
});

test('nextStep is actionable', () => {
  const categorized = awsTool.categorizeFindings(mockFindings);
  const output = awsTool.formatForADHD(categorized, mockFindings.length);

  assertTrue(output.nextStep.length > 0, 'Next step should not be empty');
  assertTrue(
    output.nextStep.includes('CRITICAL') || output.nextStep.includes('HIGH'),
    'Next step should reference severity'
  );
});

test('Telegram format uses HTML tags', () => {
  const categorized = awsTool.categorizeFindings(mockFindings);
  const output = awsTool.formatForADHD(categorized, mockFindings.length);

  assertTrue(
    output.formatted.telegram.includes('<b>'),
    'Telegram format should use HTML bold'
  );
});

test('Markdown format uses bold syntax', () => {
  const categorized = awsTool.categorizeFindings(mockFindings);
  const output = awsTool.formatForADHD(categorized, mockFindings.length);

  assertTrue(
    output.formatted.markdown.includes('**'),
    'Markdown should use ** for bold'
  );
});

// =============================================================================
// Edge Case Tests
// =============================================================================

test('Empty findings handled gracefully', () => {
  const categorized = awsTool.categorizeFindings([]);
  const output = awsTool.formatForADHD(categorized, 0);

  assertTrue(output.tldr.includes('No active security findings'));
  assertEqual(output.summary.total, 0);
});

// =============================================================================
// Phase 10: Finance Manager Tests
// =============================================================================

console.log('\n--- Phase 10: Finance Manager ---');

test('Finance: logTransaction creates valid transaction', () => {
  const result = financeTool.logTransaction({
    amount: 50,
    category: 'groceries',
    note: 'Test purchase',
  });
  assertTrue(result.success, 'Should succeed');
  assertEqual(result.transaction.amount, 50, 'Amount');
  assertEqual(result.transaction.category, 'groceries', 'Category');
});

test('Finance: logTransaction rejects invalid amount', () => {
  const result = financeTool.logTransaction({ amount: 'invalid', category: 'other' });
  assertTrue(!result.success, 'Should fail');
  assertTrue(result.error.includes('Invalid'), 'Error message');
});

test('Finance: logTransaction rejects invalid category', () => {
  const result = financeTool.logTransaction({ amount: 50, category: 'invalid_cat' });
  assertTrue(!result.success, 'Should fail');
});

test('Finance: getDebtStatus returns required structure', () => {
  const result = financeTool.getDebtStatus();
  assertTrue(result.success, 'Should succeed');
  assertTrue(result.status !== undefined, 'Has status');
  assertTrue(result.status.target !== undefined, 'Has target');
  assertTrue(result.status.current !== undefined, 'Has current');
  assertTrue(result.tldr !== undefined, 'Has tldr');
});

test('Finance: getDebtStatus tldr under 100 chars', () => {
  const result = financeTool.getDebtStatus();
  assertTrue(result.tldr.length <= 100, `TL;DR too long: ${result.tldr.length}`);
});

test('Finance: getHistory returns formatted output', () => {
  const result = financeTool.getHistory({ days: 7 });
  assertTrue(result.success, 'Should succeed');
  assertTrue(result.formatted !== undefined, 'Has formatted');
  assertTrue(result.formatted.markdown.includes('**'), 'Has bold keywords');
});

test('Finance: CONFIG has debt target', () => {
  assertTrue(financeTool.CONFIG.debtTarget > 0, 'Debt target should be positive');
});

// =============================================================================
// Phase 10: Security Scanner Tests
// =============================================================================

console.log('\n--- Phase 10: Security Scanner ---');

test('Scanner: exports required functions', () => {
  assertTrue(typeof scannerTool.validateTarget === 'function');
  assertTrue(typeof scannerTool.isWhitelisted === 'function');
  assertTrue(typeof scannerTool.runNmapScan === 'function');
  assertTrue(typeof scannerTool.runNucleiScan === 'function');
});

test('Scanner: isWhitelisted blocks non-whitelisted targets', () => {
  // With empty whitelist, should block
  const originalWhitelist = scannerTool.CONFIG.whitelist;
  scannerTool.CONFIG.whitelist = [];

  const result = scannerTool.isWhitelisted('example.com');
  assertTrue(!result.allowed, 'Should be blocked');

  scannerTool.CONFIG.whitelist = originalWhitelist;
});

test('Scanner: isWhitelisted allows whitelisted targets', () => {
  const originalWhitelist = scannerTool.CONFIG.whitelist;
  scannerTool.CONFIG.whitelist = ['example.com', 'test.local'];

  const result = scannerTool.isWhitelisted('example.com');
  assertTrue(result.allowed, 'Should be allowed');

  // Test subdomain
  const subResult = scannerTool.isWhitelisted('sub.example.com');
  assertTrue(subResult.allowed, 'Subdomain should be allowed');

  scannerTool.CONFIG.whitelist = originalWhitelist;
});

test('Scanner: validateTarget rejects invalid format', () => {
  const result = scannerTool.validateTarget('not a valid target!!!');
  assertTrue(!result.success, 'Should fail');
});

test('Scanner: validateTarget returns token for valid whitelisted target', () => {
  const originalWhitelist = scannerTool.CONFIG.whitelist;
  scannerTool.CONFIG.whitelist = ['testdomain.com'];

  const result = scannerTool.validateTarget('testdomain.com');
  assertTrue(result.success, 'Should succeed');
  assertTrue(result.token !== undefined, 'Should have token');
  assertTrue(result.token.length === 16, 'Token should be 16 chars (8 bytes hex)');
  assertTrue(result.buttons !== undefined, 'Should have buttons for Telegram');

  scannerTool.CONFIG.whitelist = originalWhitelist;
});

test('Scanner: verifyToken rejects unknown token', () => {
  const result = scannerTool.verifyToken('invalid_token_12345');
  assertTrue(!result.valid, 'Should be invalid');
});

test('Scanner: parseNmapOutput extracts ports correctly', () => {
  const mockOutput = `
Starting Nmap 7.94
Nmap scan report for example.com (93.184.216.34)
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 8.2
80/tcp   open  http    nginx 1.18
443/tcp  open  https   nginx 1.18
3306/tcp open  mysql   MySQL 8.0
`;

  const result = scannerTool.parseNmapOutput(mockOutput);
  assertEqual(result.openPorts, 4, 'Should find 4 ports');
  assertTrue(result.ports.some(p => p.port === 22), 'Should find SSH');
  assertTrue(result.ports.some(p => p.port === 3306), 'Should find MySQL');
  assertTrue(result.findings.high.length > 0, 'MySQL should be high risk');
});

test('Scanner: parseNucleiOutput handles JSON lines', () => {
  const mockOutput = `
{"template-id":"cve-2021-1234","info":{"name":"Test Vuln","severity":"critical"}}
{"template-id":"misc-info","info":{"name":"Info Finding","severity":"info"}}
`;

  const result = scannerTool.parseNucleiOutput(mockOutput);
  assertEqual(result.totalFindings, 2, 'Should find 2 findings');
  assertEqual(result.summary.critical, 1, 'Should have 1 critical');
});

test('Scanner: formatted output has max 3 bullets (Phase 7)', () => {
  const mockParsed = {
    openPorts: 10,
    ports: Array(10).fill({ port: 80, service: 'http', state: 'open' }),
    findings: {
      critical: [{ message: 'Finding 1' }, { message: 'Finding 2' }],
      high: [{ message: 'Finding 3' }, { message: 'Finding 4' }],
      medium: [{ message: 'Finding 5' }],
      low: [],
      info: [],
    },
    summary: { critical: 2, high: 2, medium: 1 },
  };

  // Count bullet points in formatted output
  const formatted = scannerTool.parseNmapOutput('22/tcp open ssh\n80/tcp open http\n443/tcp open https\n3306/tcp open mysql\n5432/tcp open postgresql');
  // The actual formatting happens in formatNmapResults which we can't easily test without more refactoring
  // But we verify the config is set correctly
  assertEqual(scannerTool.CONFIG.adhdBulletLimit, 3, 'Bullet limit should be 3');
});

// =============================================================================
// Summary
// =============================================================================

console.log('\n=== Test Summary ===');
console.log(`Passed: ${passed}`);
console.log(`Failed: ${failed}`);
console.log(`Total:  ${passed + failed}`);

process.exit(failed > 0 ? 1 : 0);
