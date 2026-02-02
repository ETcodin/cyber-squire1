# Documentation Strategy: 4-Version System

This project maintains **4 distinct documentation versions** for different audiences and security levels.

---

## Version Overview

### 1. **Public Portfolio** (This Repo - GitHub Public)
**Purpose:** Showcase technical skills to employers/recruiters
**Audience:** Hiring managers, technical recruiters, potential employers
**Security:** Fully sanitized - no real credentials, generic domains/IPs

**Contains:**
- [README.md](README.md) - Portfolio-ready overview with cost/security metrics
- [docs/Employment_Proof.md](docs/Employment_Proof.md) - Business case & architecture
- [docs/ARCHITECTURE_DIAGRAMS.md](docs/ARCHITECTURE_DIAGRAMS.md) - Visual diagrams & security model
- All generic examples (admin@yourdomain.com, n8n.yourdomain.com)

**Push to:** `github.com/YOUR_USERNAME/cyber-squire-ops` (PUBLIC)

---

### 2. **Technical Vault** (This Repo - Included in Public)
**Purpose:** Deep technical reference for advanced readers
**Audience:** DevOps engineers, security architects, technical interviewers
**Security:** Technical details only, no real credentials

**Contains:**
- [docs/Technical_Vault.md](docs/Technical_Vault.md) - 15+ pages of system specs
- Database tuning parameters
- Memory allocation strategies
- Network topology
- Performance benchmarks

**Included in:** Public repo (safe to share)

---

### 3. **ADHD Runbook** (This Repo - Included in Public)
**Purpose:** Simple operations guide without technical jargon
**Audience:** Non-technical operators, emergency recovery
**Security:** Operational procedures only, no credentials

**Contains:**
- [docs/ADHD_Runbook.md](docs/ADHD_Runbook.md) - Copy-paste commands
- Daily health checks
- Common problems + fixes
- Emergency procedures
- No assumptions about technical knowledge

**Included in:** Public repo (safe to share)

---

### 4. **Private Operations Manual** (Separate Private Repo)
**Purpose:** Real production configuration with actual credentials
**Audience:** YOU ONLY (and trusted operations team)
**Security:** NEVER commit to public repo - use private repo or local-only

**Should contain:**
- Real EC2 IP addresses (54.234.155.244, etc.)
- Real domain names (n8n.your-real-domain.com)
- Real email addresses (your-real-email@domain.com)
- Actual Cloudflare Tunnel tokens
- Real PostgreSQL passwords
- Notion API keys
- Gmail API credentials
- Slack webhook URLs
- All production secrets

**Store in:**
- Option A: Private GitHub repo (github.com/YOUR_USERNAME/cd-private-ops - set to PRIVATE)
- Option B: Local encrypted directory (~/Dropbox/cd-ops-private/)
- Option C: Password manager (1Password, LastPass with secure notes)

**DO NOT:** Store in this public portfolio repo

---

## Maintaining Both Versions

### Workflow for Changes

When you make infrastructure changes, update BOTH versions:

```bash
# 1. Make changes to public portfolio version
cd /Users/et/cyber-squire-ops
# Edit files, use generic placeholders
git add .
git commit -m "Update: [description]"
git push origin main

# 2. Make changes to private version
cd /Users/et/cd-private-ops  # Or wherever you store private version
# Edit same files, use REAL values
git add .
git commit -m "Update: [description] (PRIVATE)"
git push origin main
```

### File Mapping

| Public Repo File | Private Repo File | Difference |
|------------------|-------------------|------------|
| README.md | README.md | Same content, different Contact section (real LinkedIn) |
| COREDIRECTIVE_ENGINE/.env.template | COREDIRECTIVE_ENGINE/.env | Template vs actual credentials |
| docs/ADHD_Runbook.md | docs/ADHD_Runbook.md | Generic vs real domain/IP |
| docs/Technical_Vault.md | docs/Technical_Vault.md | Same (no credentials) |
| docs/ARCHITECTURE_DIAGRAMS.md | docs/ARCHITECTURE_DIAGRAMS.md | Same (no credentials) |
| (not included) | docs/PRIVATE_OPERATIONS_MANUAL.md | Only in private repo |

---

## Security Rules

### ✅ SAFE for Public Repo
- Architecture diagrams
- Cost optimization analysis
- Security control matrix (without real values)
- Generic domain names (yourdomain.com, example.com)
- Example IPs (203.0.113.x, 192.0.2.x - RFC 5737 test addresses)
- Placeholder credentials (REPLACE_WITH_*)
- Technical explanations
- Terraform configs (with var.my_ip for dynamic injection)

### ❌ NEVER Commit to Public Repo
- Real EC2 IP addresses
- Real domain names
- Real email addresses
- Cloudflare Tunnel tokens
- PostgreSQL passwords
- API keys (Notion, Gmail, Slack)
- SSH private keys (.pem files)
- Terraform state files (contain real IPs)
- .env files with real values
- Backup files with real credentials

---

## Quick Reference Commands

### Check for Sensitive Info Before Commit
```bash
# Scan for real IPs
grep -rE "([0-9]{1,3}\.){3}[0-9]{1,3}" --include="*.md" --include="*.yaml" | grep -v "127.0.0.1" | grep -v "0.0.0.0" | grep -v "172.28.0" | grep -v "203.0.113" | grep -v "192.0.2"

# Scan for real tokens
grep -rE "(eyJ[A-Za-z0-9_-]{10,}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{48})" --include="*.md" --include="*.yaml"

# Scan for real email domains
grep -r "@" --include="*.md" --include="*.yaml" | grep -v "yourdomain.com" | grep -v "example.com"

# Check gitignore protections
git status | grep -E "\.pem|\.key|\.env$|terraform.tfstate"
# Should return nothing (files ignored)
```

### Create Private Repo (First Time)
```bash
# 1. Create new private repo on GitHub
# Go to: github.com/new
# Name: cd-private-ops
# Set: PRIVATE repository
# Don't initialize with README

# 2. Clone public repo to private location
cd ~
git clone /Users/et/cyber-squire-ops cd-private-ops
cd cd-private-ops

# 3. Change remote to private repo
git remote remove origin
git remote add origin git@github.com:YOUR_USERNAME/cd-private-ops.git

# 4. Add real values to all files
# Replace all "yourdomain.com" with real domain
# Replace all "admin@yourdomain.com" with real email
# Replace all example IPs with real IPs
# Fill in .env with real credentials

# 5. Remove .gitignore for PRIVATE_OPERATIONS_MANUAL.md
sed -i '' '/PRIVATE_OPERATIONS_MANUAL/d' .gitignore

# 6. Commit and push
git add .
git commit -m "Private operations version with real credentials"
git push -u origin main
```

---

## Syncing Changes Between Versions

### Method 1: Manual Sync (Safest)
```bash
# 1. Make changes in public repo
cd /Users/et/cyber-squire-ops
git add .
git commit -m "Update architecture diagrams"
git push

# 2. Copy changes to private repo
cd ~/cd-private-ops
cp /Users/et/cyber-squire-ops/docs/ARCHITECTURE_DIAGRAMS.md docs/
# Review changes, ensure no credentials leaked
git add docs/ARCHITECTURE_DIAGRAMS.md
git commit -m "Sync: architecture diagrams update"
git push
```

### Method 2: Git Cherry-Pick (Advanced)
```bash
# Get commit SHA from public repo
cd /Users/et/cyber-squire-ops
git log --oneline | head -1
# Example output: abc123f Update architecture

# Apply to private repo
cd ~/cd-private-ops
git cherry-pick abc123f
# Review changes, fix any conflicts
git push
```

---

## Audit Checklist (Before Public Push)

Run this before every `git push` to public repo:

```bash
cd /Users/et/cyber-squire-ops

echo "=== PRE-PUSH SECURITY AUDIT ==="

# 1. No real IPs
echo "1. Checking for real IPs..."
grep -rE "([0-9]{1,3}\.){3}[0-9]{1,3}" --include="*.md" --include="*.yaml" --include="*.tf" | \
  grep -v "127.0.0.1" | grep -v "0.0.0.0" | grep -v "172.28.0" | grep -v "172.25.0" | \
  grep -v "203.0.113" | grep -v "192.0.2" | grep -v "18.206.107" | \
  wc -l | xargs echo "   Found:"

# 2. No real tokens
echo "2. Checking for real tokens..."
grep -rE "(eyJ[A-Za-z0-9_-]{10,})" --include="*.md" --include="*.yaml" | \
  wc -l | xargs echo "   Found:"

# 3. No real emails
echo "3. Checking for real emails..."
grep -r "@" --include="*.md" --include="*.yaml" | \
  grep -v "yourdomain.com" | grep -v "example.com" | \
  wc -l | xargs echo "   Found:"

# 4. gitignore working
echo "4. Checking gitignore protection..."
git status | grep -E "\.pem|\.key|\.env$|terraform.tfstate" | \
  wc -l | xargs echo "   Unprotected files:"

echo ""
echo "✅ If all counts are 0, safe to push!"
echo "❌ If any counts > 0, review files before pushing"
```

---

## Example: Two-Repo Structure

```
Public Portfolio Repo (github.com/you/cyber-squire-ops)
├── README.md (generic, portfolio-focused)
├── docs/
│   ├── Employment_Proof.md (sanitized)
│   ├── Technical_Vault.md (no credentials)
│   ├── ADHD_Runbook.md (generic examples)
│   └── ARCHITECTURE_DIAGRAMS.md (sanitized)
├── COREDIRECTIVE_ENGINE/
│   ├── .env.template (placeholders only)
│   └── docker-compose.yaml (yourdomain.com)
└── .gitignore (blocks .env, .pem, tfstate)

Private Operations Repo (github.com/you/cd-private-ops - PRIVATE)
├── README.md (real domain, real contact info)
├── docs/
│   ├── Employment_Proof.md (same as public)
│   ├── Technical_Vault.md (same as public)
│   ├── ADHD_Runbook.md (real domains/IPs)
│   ├── ARCHITECTURE_DIAGRAMS.md (real examples)
│   └── PRIVATE_OPERATIONS_MANUAL.md (ALL real credentials)
├── COREDIRECTIVE_ENGINE/
│   ├── .env (REAL credentials)
│   └── docker-compose.yaml (real domain)
└── .gitignore (does NOT block PRIVATE_OPERATIONS_MANUAL.md)
```

---

## Questions & Answers

**Q: Can I just use one repo with branches?**
A: Not recommended. Git history retains deleted credentials. Use separate repos.

**Q: What if I accidentally commit real credentials to public repo?**
A:
1. Immediately revoke the credential (Cloudflare, AWS, etc.)
2. Run: `git filter-branch` or `BFG Repo-Cleaner` to remove from history
3. Force push: `git push --force`
4. Generate new credentials

**Q: How do I remember which version I'm editing?**
A: Check git remote: `git remote -v`
- Public repo: github.com/YOU/cyber-squire-ops
- Private repo: github.com/YOU/cd-private-ops

**Q: Can I keep private version locally instead of GitHub?**
A: Yes! Just don't set up a remote. Keep in `~/cd-private-ops/` and back up to encrypted cloud storage.

---

**Last Updated:** 2026-01-29
**Maintained By:** Emmanuel Tigoue
