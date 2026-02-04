# Phase 10: Extended Tools - State Tracker

## Overview
Implement specialized tools for finance management and security scanning.

## Progress: 0/2 Plans Completed (0%)

---

## 10-01: Finance Manager ❌ NOT STARTED
**Status**: Pending
**Dependencies**: None
**Blocker**: None

### Tasks
- [ ] Create finance database schema
- [ ] Implement NLP transaction parsing
- [ ] Log transaction to database
- [ ] Implement debt burn-down calculation
- [ ] Format debt status response
- [ ] Add spending summary command

### Artifacts
- [ ] tool_finance_manager.json workflow
- [ ] finance_schema.sql
- [ ] Transaction parsing logic
- [ ] Debt tracking calculations

---

## 10-02: Security Scan ❌ NOT STARTED
**Status**: Pending
**Dependencies**: Phase 08 (Interactive UI for confirmation buttons)
**Blocker**: None

### Tasks
- [ ] Create target whitelist schema
- [ ] Implement target validation
- [ ] Add confirmation flow with button
- [ ] Implement Nmap scan execution
- [ ] Implement Nuclei vulnerability scan
- [ ] Format scan results with severity indicators
- [ ] Add rate limiting for scans

### Artifacts
- [ ] tool_security_scan.json workflow
- [ ] security_whitelist.sql
- [ ] Nmap integration
- [ ] Nuclei integration
- [ ] Rate limiting implementation

---

## SQL Schema Requirements

### Finance Manager Tables
```sql
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    category VARCHAR(100),
    description TEXT,
    transaction_date DATE DEFAULT CURRENT_DATE,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_debt_payment BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS debt_tracking (
    id SERIAL PRIMARY KEY,
    total_debt DECIMAL(10, 2) NOT NULL,
    target_debt DECIMAL(10, 2) DEFAULT 0,
    current_balance DECIMAL(10, 2),
    monthly_burn_rate DECIMAL(10, 2),
    projected_payoff_date DATE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Security Scanner Tables
```sql
CREATE TABLE IF NOT EXISTS allowed_scan_targets (
    id SERIAL PRIMARY KEY,
    target VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    owner VARCHAR(100),
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_scanned TIMESTAMP
);

CREATE TABLE IF NOT EXISTS scan_history (
    id SERIAL PRIMARY KEY,
    target VARCHAR(255) NOT NULL,
    scan_type VARCHAR(50) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR(20),
    findings_count INTEGER,
    results JSONB,
    user_id BIGINT
);
```

---

## Success Criteria (from ROADMAP.md)

1. **SC-10.1**: "Log $50 for groceries" creates transaction record
2. **SC-10.2**: "Debt status" shows current balance and burn rate
3. **SC-10.3**: "Scan example.com" shows confirmation button before execution
4. **SC-10.4**: Scan results formatted with severity indicators
5. **SC-10.5**: Scans restricted to whitelisted targets only

---

## Finance Manager Specifications

### Transaction Categories
- Groceries
- Rent
- Utilities
- Transportation
- Entertainment
- Debt Payment
- Other

### NLP Parsing Patterns
| Input | Amount | Category | Debt Payment |
|-------|--------|----------|--------------|
| "Log $50 for groceries" | $50 | Groceries | No |
| "Spent $120 on gas" | $120 | Transportation | No |
| "Paid $500 debt" | $500 | Debt Payment | Yes |
| "$25 coffee" | $25 | Other | No |

### Debt Status Output
```
**Debt Burn-Down Status**

💰 Current balance: **$58,450**
📉 Monthly burn rate: **$1,550/month**
🎯 Target: **$0**
📅 Projected payoff: **Aug 15, 2028**

**Progress:** 2.6% complete
[▓░░░░░░░░░]

**Next step:** Keep up the momentum!
```

### Spending Summary Output
```
**Spending Summary (Last 7 Days)**

Total: **$345**

Top categories:
• Groceries: $120 (3 transactions)
• Transportation: $80 (2 transactions)
• Entertainment: $45 (1 transaction)

**Next step:** Review categories to find savings opportunities
```

---

## Security Scanner Specifications

### Whitelist Default Targets
- tigouetheory.com
- cyber-squire.tigouetheory.com
- 54.234.155.244 (EC2 instance)

### Scan Commands
| Command | Tool | Parameters |
|---------|------|------------|
| Port Scan | Nmap | `-sV -T4 --top-ports 100` |
| Vuln Scan | Nuclei | `-severity critical,high -json -silent` |

### Rate Limits
- Max 1 scan per target per hour
- Max 5 total scans per user per day

### Severity Indicators
- 🔴 Critical
- 🟠 High
- 🟡 Medium
- 🟢 Low

### Scan Results Output
```
**Security Scan Results: tigouetheory.com**

**Port Scan (Nmap):**
• Port 80: HTTP (nginx 1.21.6)
• Port 443: HTTPS (nginx 1.21.6)
• Port 22: SSH (OpenSSH 8.7)

**Vulnerabilities (Nuclei):**
✅ No critical/high vulnerabilities found

Scan completed: Feb 4, 2026 18:45 UTC
```

---

## Testing Checklist

### Finance Manager (10-01)
- [ ] "Log $50 for groceries" creates transaction
- [ ] Transaction appears in database
- [ ] Confirmation message shows amount and category
- [ ] "Paid $500 debt" flagged as debt payment
- [ ] "Debt status" shows current balance
- [ ] "Debt status" shows burn rate
- [ ] "Debt status" shows projected payoff
- [ ] Progress bar displays correctly
- [ ] "Spending summary" shows top 3 categories
- [ ] Summary limited to max 3 items (ADHD formatting)

### Security Scanner (10-02)
- [ ] "Scan unauthorized.com" rejected
- [ ] "Scan tigouetheory.com" shows confirmation
- [ ] Click Yes executes scan
- [ ] Click No cancels scan
- [ ] Nmap results show open ports
- [ ] Nuclei results show vulnerabilities (if any)
- [ ] Severity indicators appear (🔴 🟠 🟡 🟢)
- [ ] Results limited to max 3 findings (ADHD formatting)
- [ ] Second scan within 1 hour rate limited
- [ ] Scan logged to scan_history table

---

## Integration Points

### With AI Routing (Phase 3)
- Finance Manager routed via "log", "spent", "debt", "spending"
- Security Scanner routed via "scan", "nmap", "security"

### With Output Formatting (Phase 7)
- Both tools use ADHD formatting (bold keywords, max 3 bullets)
- Both tools include "Next step" line
- Progress bar for debt status (visual element)

### With Interactive UI (Phase 8)
- Security Scanner uses Yes/No confirmation buttons
- Could add priority buttons for transaction categories

---

## External Dependencies

### Finance Manager
- None (pure database operations)

### Security Scanner
- Nmap: Install on EC2 via `sudo yum install nmap -y`
- Nuclei: Install from GitHub releases
  ```bash
  curl -L https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_3.x.x_linux_amd64.zip -o nuclei.zip
  unzip nuclei.zip
  sudo mv nuclei /usr/local/bin/
  nuclei -update-templates
  ```

---

## Notes

- **Finance tracking**: All amounts in USD, 2 decimal precision
- **Debt goal**: $60,000 → $0 (configurable in debt_tracking table)
- **Security scanning**: Only on whitelisted targets to prevent abuse
- **Rate limiting**: Prevents excessive EC2 resource usage
- **Scan timeout**: 5 minutes max (some scans take time)
- **Privacy**: No PII in transaction descriptions

---

Last Updated: 2026-02-04 by Claude Sonnet 4.5
