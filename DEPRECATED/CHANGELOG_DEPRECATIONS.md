# Deprecation Changelog

This document tracks all deprecated content in the CoreDirective Automation Engine project.

---

## 2026-01-30: Documentation Audit & Model Standardization

### Deprecated: Workflow Files Using Qwen 2.5 Models

**Reason:** System standardized on Qwen 3 8B quantized model (`qwen3:8b-instruct-q4_K_M`) for all AI inference tasks.

**Impact:** Workflows referencing Qwen 2.5 variants would fail because these models are not installed on the production Ollama instance.

**Migration Actions:**
- Updated 7 workflow files to use `qwen3:8b-instruct-q4_K_M`
- Updated 2 documentation files (ARCHITECTURE_DIAGRAMS.md, QUICKSTART.md)

**Files Updated:**
1. `workflow_gumroad_solvency.json` (line 195)
   - OLD: `qwen2.5:7b`
   - NEW: `qwen3:8b-instruct-q4_K_M`

2. `workflow_notion_task_manager.json` (line 54)
   - OLD: `qwen2.5:14b`
   - NEW: `qwen3:8b-instruct-q4_K_M`

3. `workflow_ai_router.json` (line 48)
   - OLD: `qwen2.5:32b`
   - NEW: `qwen3:8b-instruct-q4_K_M`

4. `workflow_moltbot_generator.json` (lines 20, 76)
   - OLD: `qwen2.5:32b` (2 occurrences)
   - NEW: `qwen3:8b-instruct-q4_K_M`

5. `workflow_youtube_factory.json` (line 50)
   - OLD: `qwen2.5:32b`
   - NEW: `qwen3:8b-instruct-q4_K_M`

6. `ARCHITECTURE_DIAGRAMS.md` (line 157)
   - OLD: `qwen2.5-coder:7b`
   - NEW: `qwen3:8b-instruct-q4_K_M`

7. `COREDIRECTIVE_ENGINE/QUICKSTART.md` (line 245)
   - OLD: `qwen2.5:32b`
   - NEW: `qwen3:8b-instruct-q4_K_M`

**Technical Context:**
- Qwen 3 8B provides comparable quality to Qwen 2.5 variants while using less memory
- 4-bit quantization allows the model to fit within 7.5GB RAM allocation on t3.xlarge
- Standardization simplifies troubleshooting and resource management

---

## 2026-01-29: Engine Configuration Standardization

### Deprecated: CD_ENGINE_MASTER Directory

**Reason:** Naming convention mismatch between development and production configurations.

**Migration Path:**
- Production standardized on `COREDIRECTIVE_ENGINE/` with hyphen-based service names
- Hyphen-based naming aligns with Docker/Kubernetes conventions
- Improves compatibility with container orchestration tools

**Key Differences:**

| Component | CD_ENGINE_MASTER (OLD) | COREDIRECTIVE_ENGINE (NEW) |
|-----------|------------------------|---------------------------|
| PostgreSQL | cd_postgres | cd-service-db |
| n8n | cd_n8n | cd-service-n8n |
| Ollama | cd_brain_ollama | cd-service-ollama |
| Tunnel | cd_cloudflare_tunnel | tunnel-cyber-squire |
| Volumes | CD_POSTGRES_DATA | cd-vol-postgres |
| Network | cd_net | cd-net (unchanged) |

**Status:**
- Directory moved to `DEPRECATED/CD_ENGINE_MASTER/`
- Kept for historical reference and comparison
- All production deployments migrated to COREDIRECTIVE_ENGINE

**Documentation Updated:**
- Added deprecation warning to CD_ENGINE_MASTER/docker-compose.yaml
- Created CD_ENGINE_MASTER/README.md explaining legacy status
- Updated all references in main documentation to point to COREDIRECTIVE_ENGINE

---

## 2026-01-30: Documentation Path & User Corrections

### Fixed: SSH User and Path Mismatches

**Issue:** Documentation used `ubuntu` user and `/home/ubuntu` paths, but actual production system uses `ec2-user` and `/home/ec2-user`.

**Reason:** Initial development used Ubuntu AMI, production migrated to Amazon Linux 2023 / RHEL 9 which uses `ec2-user` as default system user.

**Files Corrected:**
1. `docs/Employment_Proof.md` (line 137) - Portfolio document for job applications
2. `docs/Technical_Vault.md` (9 lines) - Deep technical reference guide
3. `docs/ADHD_Runbook.md` (line 94) - Daily operations guide
4. `.github/copilot-instructions.md` (4 lines) - AI coding assistant configuration

**Impact:** Users following old documentation would experience authentication failures and "directory not found" errors.

---

### Fixed: Database Configuration Mismatches

**Issue:** `.env.template` had incorrect database name and user that didn't match production system.

**Files Corrected:**
- `COREDIRECTIVE_ENGINE/.env.template`
  - Database name: `coredirective_db` → `cd_automation_db`
  - Database user: `coredirective` → `cd_admin`
  - Storage path: `/mnt/gdrive` → `/home/ec2-user/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT`
  - Added: `CD_BACKUP_PATH` variable
  - Domain: `yourdomain.com` → `yourdomain.com` (generic placeholder)

**Impact:** New deployments using `.env.template` would fail database connectivity without manual corrections.

---

### Fixed: Moltbot/Clawdbot Naming Inconsistency

**Issue:** `docs/PRIVATE_OPERATIONS_MANUAL.md` referenced both "Moltbot" and "Clawdbot" as if they were different services.

**Clarification:** These are the same service. Name evolved from "Clawdbot" (original) to "Moltbot" (current).

**Standardization:** All documentation now consistently uses "Moltbot" only.

---

## Future Deprecations

When deprecating content in the future, follow this template:

```markdown
## YYYY-MM-DD: [Brief Title]

### Deprecated: [What Was Deprecated]

**Reason:** [Why it was deprecated]

**Impact:** [What breaks if you use the old way]

**Migration Actions:**
- [List of specific changes made]

**Files Updated:**
- [List of files with line numbers]

**Technical Context:**
- [Additional context for future reference]
```

---

**Maintained By:** Emmanuel Tigoue
**Project:** CoreDirective Automation Engine (Operation Nuclear)
**Last Updated:** 2026-01-30
