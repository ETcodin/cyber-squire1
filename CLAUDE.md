# CLAUDE.md - Session State & Context

## Repository Status
- **GitHub Repo:** https://github.com/ETcodin/cyber-squire1
- **Visibility:** Public
- **Last Updated:** 2026-02-02

## Completed Tasks (This Session)
1. ✅ Destroyed old `cyber-squire` repo (had sensitive tfstate/tfplan in history)
2. ✅ Created fresh `cyber-squire1` repo with clean history
3. ✅ Sanitized all files:
   - Removed hardcoded API keys from scripts
   - Replaced `tigouetheory.com` → `yourdomain.com` throughout
   - Updated `Employment_Proof.md` to ISO 27001 format (no PII)
   - Added Mermaid.js diagram to `ARCHITECTURE_DIAGRAMS.md`
4. ✅ Enhanced `.gitignore` for comprehensive secret protection
5. ✅ Validated Terraform uses `var.key_name` (no hardcoded `.pem` paths)

## ⚠️ CRITICAL: Credential Rotation Required
The following credentials were exposed in the old repo history. **ROTATE IMMEDIATELY:**

| Service | Key Pattern | Dashboard |
|---------|-------------|-----------|
| Anthropic | `sk-ant-api03-...` | https://console.anthropic.com |
| GitHub | `ghp_xXq2...` | https://github.com/settings/tokens |
| Google OAuth | `GOCSPX-...` | https://console.cloud.google.com/apis/credentials |
| Gumroad | `HNdY0t__...` | https://app.gumroad.com/settings/advanced |
| Notion | `ntn_303...` | https://www.notion.so/my-integrations |
| Perplexity | `pplx-...` | https://www.perplexity.ai/settings/api |
| n8n API Key | `35d4a05c-...` | Regenerate in n8n settings |

## Local Files (Git-Ignored, On Disk)
These files exist locally but are NOT in the repo:
- `cyber-squire-key.pem` - SSH private key
- `cyber-squire-ops.pem` - SSH private key
- `terraform.tfstate` - Infrastructure state
- `cyber-squire.tfplan` - Terraform plan
- `credentials_vault.json` - API keys (reference for rotation)

## Architecture Overview
```
AWS t3.xlarge (16GB RAM)
├── PostgreSQL 16 (4GB) - Workflow state
├── n8n (2GB) - Orchestration
├── Ollama + Qwen 3 8B (7.5GB) - Local AI inference
└── Cloudflare Tunnel - Zero-trust access
```

## Key Directories
- `/terraform/simple-ec2/` - Quick-start deployment
- `/terraform/cd-aws-automation/` - Production-grade with NAT instance
- `/COREDIRECTIVE_ENGINE/` - Docker Compose stack
- `/docs/` - Architecture diagrams, runbooks, compliance docs

## Next Session Context
When resuming work, prioritize:
1. Credential rotation (if not done)
2. Any pending deployment tasks
3. Check `docs/ADHD_Runbook.md` for operational notes
