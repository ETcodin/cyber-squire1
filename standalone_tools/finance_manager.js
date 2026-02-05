/**
 * Finance Manager - Standalone Tool
 * Phase 10: Extended Tools (Cyber-Squire Telegram Router)
 *
 * Purpose: Log transactions and track debt burn-down progress.
 * Designed for ADHD-friendly financial visibility via Telegram.
 *
 * Features:
 *   - Log transactions with category tagging
 *   - Track debt balance against $60K target
 *   - Calculate burn rate and projected payoff date
 *   - ADHD-friendly formatted summaries
 *
 * Environment Variables:
 *   CD_DB_HOST     - PostgreSQL host (default: localhost)
 *   CD_DB_PORT     - PostgreSQL port (default: 5432)
 *   CD_DB_USER     - Database user
 *   CD_DB_PASS     - Database password
 *   CD_DB_NAME     - Database name
 *   CD_DEBT_TARGET - Debt payoff target (default: 60000)
 *
 * Usage:
 *   node finance_manager.js log --amount=50 --category=groceries --note="Weekly shopping"
 *   node finance_manager.js status
 *   node finance_manager.js history --days=30
 */

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
  debtTarget: parseFloat(process.env.CD_DEBT_TARGET || '60000'),
  currency: '$',
  categories: [
    'income', 'groceries', 'utilities', 'rent', 'transport',
    'healthcare', 'entertainment', 'debt_payment', 'savings', 'other'
  ],
  adhdBulletLimit: 3,
};

// In-memory storage for standalone mode (replace with PostgreSQL in production)
let transactions = [];
let currentDebt = CONFIG.debtTarget;

// ============================================================================
// TRANSACTION OPERATIONS
// ============================================================================

/**
 * Log a new transaction
 */
function logTransaction(options) {
  const { amount, category, note = '', isDebtPayment = false } = options;

  // Validate
  if (!amount || isNaN(amount)) {
    return {
      success: false,
      error: 'Invalid amount',
      tldr: '❌ Specify a valid amount',
    };
  }

  const normalizedCategory = category?.toLowerCase() || 'other';
  if (!CONFIG.categories.includes(normalizedCategory)) {
    return {
      success: false,
      error: `Invalid category. Valid: ${CONFIG.categories.join(', ')}`,
      tldr: `❌ Unknown category "${category}"`,
    };
  }

  const transaction = {
    id: `txn_${Date.now()}`,
    amount: parseFloat(amount),
    category: normalizedCategory,
    note: note.substring(0, 200),
    timestamp: new Date().toISOString(),
    isDebtPayment: normalizedCategory === 'debt_payment' || isDebtPayment,
  };

  transactions.push(transaction);

  // Update debt if it's a payment
  if (transaction.isDebtPayment && transaction.amount > 0) {
    currentDebt = Math.max(0, currentDebt - transaction.amount);
  }

  return {
    success: true,
    transaction,
    tldr: `✅ Logged ${CONFIG.currency}${amount} for ${normalizedCategory}`,
    formatted: formatTransactionConfirmation(transaction),
  };
}

/**
 * Get current debt status with burn-down analysis
 */
function getDebtStatus() {
  const debtPayments = transactions.filter(t => t.isDebtPayment);
  const totalPaid = debtPayments.reduce((sum, t) => sum + t.amount, 0);
  const percentPaid = ((totalPaid / CONFIG.debtTarget) * 100).toFixed(1);

  // Calculate monthly burn rate
  const burnRate = calculateMonthlyBurnRate(debtPayments);
  const projectedPayoffDate = calculatePayoffDate(currentDebt, burnRate.monthly);

  const status = {
    target: CONFIG.debtTarget,
    current: currentDebt,
    totalPaid,
    percentPaid: parseFloat(percentPaid),
    remaining: currentDebt,
    burnRate,
    projectedPayoff: projectedPayoffDate,
  };

  return {
    success: true,
    status,
    tldr: generateDebtTLDR(status),
    formatted: formatDebtStatus(status),
  };
}

/**
 * Get transaction history
 */
function getHistory(options = {}) {
  const { days = 30, category = null } = options;

  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);

  let filtered = transactions.filter(t => new Date(t.timestamp) >= cutoff);

  if (category) {
    filtered = filtered.filter(t => t.category === category.toLowerCase());
  }

  // Sort by most recent first
  filtered.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  // Summarize by category
  const byCategory = {};
  filtered.forEach(t => {
    if (!byCategory[t.category]) {
      byCategory[t.category] = { total: 0, count: 0 };
    }
    byCategory[t.category].total += t.amount;
    byCategory[t.category].count++;
  });

  const totalSpent = filtered
    .filter(t => !t.isDebtPayment && t.category !== 'income')
    .reduce((sum, t) => sum + t.amount, 0);

  const totalIncome = filtered
    .filter(t => t.category === 'income')
    .reduce((sum, t) => sum + t.amount, 0);

  return {
    success: true,
    period: `${days} days`,
    transactions: filtered.slice(0, 10), // Limit for display
    totalCount: filtered.length,
    byCategory,
    summary: {
      totalSpent,
      totalIncome,
      netFlow: totalIncome - totalSpent,
    },
    tldr: generateHistoryTLDR(filtered, totalSpent, totalIncome, days),
    formatted: formatHistory(filtered, byCategory, days),
  };
}

// ============================================================================
// CALCULATIONS
// ============================================================================

/**
 * Calculate monthly burn rate from payment history
 */
function calculateMonthlyBurnRate(payments) {
  if (payments.length === 0) {
    return { monthly: 0, weekly: 0, trend: 'no_data' };
  }

  // Get date range
  const dates = payments.map(p => new Date(p.timestamp));
  const oldest = Math.min(...dates);
  const newest = Math.max(...dates);
  const daysDiff = Math.max(1, (newest - oldest) / (1000 * 60 * 60 * 24));

  const total = payments.reduce((sum, p) => sum + p.amount, 0);
  const daily = total / daysDiff;
  const monthly = daily * 30;
  const weekly = daily * 7;

  // Trend analysis (last 30 days vs previous 30 days)
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const sixtyDaysAgo = new Date();
  sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60);

  const recentPayments = payments.filter(p => new Date(p.timestamp) >= thirtyDaysAgo);
  const olderPayments = payments.filter(p => {
    const d = new Date(p.timestamp);
    return d >= sixtyDaysAgo && d < thirtyDaysAgo;
  });

  const recentTotal = recentPayments.reduce((sum, p) => sum + p.amount, 0);
  const olderTotal = olderPayments.reduce((sum, p) => sum + p.amount, 0);

  let trend = 'stable';
  if (olderTotal > 0) {
    const change = ((recentTotal - olderTotal) / olderTotal) * 100;
    if (change > 10) trend = 'increasing';
    else if (change < -10) trend = 'decreasing';
  }

  return {
    monthly: Math.round(monthly * 100) / 100,
    weekly: Math.round(weekly * 100) / 100,
    trend,
  };
}

/**
 * Calculate projected payoff date
 */
function calculatePayoffDate(remaining, monthlyRate) {
  if (monthlyRate <= 0) {
    return { date: null, months: null, message: 'Need payment data to project' };
  }

  const monthsRemaining = Math.ceil(remaining / monthlyRate);
  const payoffDate = new Date();
  payoffDate.setMonth(payoffDate.getMonth() + monthsRemaining);

  return {
    date: payoffDate.toISOString().split('T')[0],
    months: monthsRemaining,
    message: `~${monthsRemaining} months at current rate`,
  };
}

// ============================================================================
// ADHD-FRIENDLY FORMATTING (Phase 7 Compliance)
// ============================================================================

/**
 * Format transaction confirmation
 */
function formatTransactionConfirmation(txn) {
  const emoji = txn.isDebtPayment ? '💳' : getCategoryEmoji(txn.category);

  return {
    markdown: `**Transaction Logged**\n\n${emoji} **${CONFIG.currency}${txn.amount}** → ${txn.category}\n${txn.note ? `📝 ${txn.note}\n` : ''}\n**Next step:** Check your balance with "debt status"`,
    telegram: `<b>Transaction Logged</b>\n\n${emoji} <b>${CONFIG.currency}${txn.amount}</b> → ${txn.category}\n${txn.note ? `📝 ${txn.note}\n` : ''}\n<b>Next step:</b> Check your balance with "debt status"`,
  };
}

/**
 * Generate debt status TL;DR
 */
function generateDebtTLDR(status) {
  const pct = status.percentPaid;
  if (pct >= 100) {
    return '🎉 DEBT FREE! Target reached!';
  } else if (pct >= 75) {
    return `🟢 ${pct}% paid - ${CONFIG.currency}${status.remaining.toLocaleString()} remaining`;
  } else if (pct >= 50) {
    return `🟡 ${pct}% paid - Halfway there!`;
  } else if (pct >= 25) {
    return `🟠 ${pct}% paid - Keep pushing!`;
  }
  return `🔴 ${pct}% paid - ${CONFIG.currency}${status.remaining.toLocaleString()} to go`;
}

/**
 * Format debt status for display
 */
function formatDebtStatus(status) {
  const progressBar = generateProgressBar(status.percentPaid);
  const trendEmoji = status.burnRate.trend === 'increasing' ? '📈' :
                     status.burnRate.trend === 'decreasing' ? '📉' : '➡️';

  const lines = [
    `**Debt Burn-Down**`,
    ``,
    `${progressBar} **${status.percentPaid}%**`,
    ``,
    `• **Paid:** ${CONFIG.currency}${status.totalPaid.toLocaleString()}`,
    `• **Remaining:** ${CONFIG.currency}${status.remaining.toLocaleString()}`,
    `• **Monthly rate:** ${CONFIG.currency}${status.burnRate.monthly.toLocaleString()} ${trendEmoji}`,
    ``,
    `**Projected payoff:** ${status.projectedPayoff.message}`,
    ``,
    `**Next step:** Log a debt payment to accelerate progress`,
  ];

  const telegramLines = lines.map(l => l.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>'));

  return {
    markdown: lines.join('\n'),
    telegram: telegramLines.join('\n'),
  };
}

/**
 * Generate history TL;DR
 */
function generateHistoryTLDR(transactions, spent, income, days) {
  const net = income - spent;
  const emoji = net >= 0 ? '🟢' : '🔴';
  return `${emoji} ${days}d: ${CONFIG.currency}${income.toLocaleString()} in, ${CONFIG.currency}${spent.toLocaleString()} out (net: ${net >= 0 ? '+' : ''}${CONFIG.currency}${net.toLocaleString()})`;
}

/**
 * Format transaction history
 */
function formatHistory(transactions, byCategory, days) {
  const lines = [
    `**Transaction History** (${days} days)`,
    ``,
  ];

  // Top 3 categories by spend (Phase 7: max 3 bullets)
  const sortedCategories = Object.entries(byCategory)
    .filter(([cat]) => cat !== 'income' && cat !== 'debt_payment')
    .sort((a, b) => b[1].total - a[1].total)
    .slice(0, CONFIG.adhdBulletLimit);

  if (sortedCategories.length > 0) {
    lines.push(`**Top Spending:**`);
    sortedCategories.forEach(([cat, data]) => {
      const emoji = getCategoryEmoji(cat);
      lines.push(`• ${emoji} **${cat}:** ${CONFIG.currency}${data.total.toLocaleString()} (${data.count}x)`);
    });
    lines.push(``);
  }

  // Recent transactions (max 3)
  if (transactions.length > 0) {
    lines.push(`**Recent:**`);
    transactions.slice(0, CONFIG.adhdBulletLimit).forEach(txn => {
      const emoji = getCategoryEmoji(txn.category);
      const date = new Date(txn.timestamp).toLocaleDateString();
      lines.push(`• ${emoji} ${CONFIG.currency}${txn.amount} ${txn.category} (${date})`);
    });

    if (transactions.length > CONFIG.adhdBulletLimit) {
      lines.push(`... and ${transactions.length - CONFIG.adhdBulletLimit} more`);
    }
  }

  lines.push(``);
  lines.push(`**Next step:** Review spending and log any missing transactions`);

  const telegramLines = lines.map(l => l.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>'));

  return {
    markdown: lines.join('\n'),
    telegram: telegramLines.join('\n'),
  };
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function generateProgressBar(percent, width = 10) {
  const filled = Math.round((percent / 100) * width);
  const empty = width - filled;
  return '█'.repeat(filled) + '░'.repeat(empty);
}

function getCategoryEmoji(category) {
  const emojis = {
    income: '💰',
    groceries: '🛒',
    utilities: '💡',
    rent: '🏠',
    transport: '🚗',
    healthcare: '🏥',
    entertainment: '🎬',
    debt_payment: '💳',
    savings: '🏦',
    other: '📦',
  };
  return emojis[category] || '📦';
}

// ============================================================================
// DATABASE OPERATIONS (PostgreSQL - for production use)
// ============================================================================

/**
 * Initialize database tables
 * Call this when deploying to production with PostgreSQL
 */
function getDatabaseSchema() {
  return `
-- Finance Manager Schema
CREATE TABLE IF NOT EXISTS transactions (
  id VARCHAR(50) PRIMARY KEY,
  amount DECIMAL(10, 2) NOT NULL,
  category VARCHAR(50) NOT NULL,
  note TEXT,
  is_debt_payment BOOLEAN DEFAULT FALSE,
  timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS debt_status (
  id SERIAL PRIMARY KEY,
  target DECIMAL(10, 2) NOT NULL,
  current_balance DECIMAL(10, 2) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast history queries
CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category);

-- Initial debt record (run once)
INSERT INTO debt_status (target, current_balance)
SELECT 60000, 60000
WHERE NOT EXISTS (SELECT 1 FROM debt_status);
`;
}

// ============================================================================
// MAIN EXECUTION / CLI
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
    console.log(`Finance Manager - Phase 10 Tool

Usage:
  node finance_manager.js log --amount=50 --category=groceries [--note="description"]
  node finance_manager.js debt_payment --amount=500 [--note="Monthly payment"]
  node finance_manager.js status
  node finance_manager.js history [--days=30] [--category=groceries]
  node finance_manager.js schema  (outputs PostgreSQL schema)

Categories: ${CONFIG.categories.join(', ')}
`);
    return;
  }

  let result;

  switch (args.command) {
    case 'log':
      result = logTransaction({
        amount: args.amount,
        category: args.category,
        note: args.note,
      });
      break;

    case 'debt_payment':
      result = logTransaction({
        amount: args.amount,
        category: 'debt_payment',
        note: args.note,
        isDebtPayment: true,
      });
      break;

    case 'status':
      result = getDebtStatus();
      break;

    case 'history':
      result = getHistory({
        days: parseInt(args.days || '30', 10),
        category: args.category,
      });
      break;

    case 'schema':
      console.log(getDatabaseSchema());
      return;

    default:
      result = {
        success: false,
        error: `Unknown command: ${args.command}`,
        tldr: `❌ Unknown command "${args.command}"`,
      };
  }

  // Output JSON for webhook consumption
  console.log(JSON.stringify(result, null, 2));

  // Print formatted version to stderr
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

// Export for module use
module.exports = {
  logTransaction,
  getDebtStatus,
  getHistory,
  calculateMonthlyBurnRate,
  calculatePayoffDate,
  getDatabaseSchema,
  CONFIG,
};
