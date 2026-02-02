# Deprecated Content Archive

**Purpose:** This directory contains legacy configurations and outdated files that are no longer in use but kept for historical reference.

**Last Updated:** 2026-01-30

---

## Contents

### 1. CD_ENGINE_MASTER/
**Status:** Deprecated as of 2026-01-29

**Description:** Legacy docker-compose configuration using old naming conventions.

**Key Differences from COREDIRECTIVE_ENGINE:**
- Uses underscore naming (`cd_postgres` vs `cd-service-db`)
- Uses underscore naming (`cd_n8n` vs `cd-service-n8n`)
- Uses underscore naming (`cd_brain_ollama` vs `cd-service-ollama`)
- Missing Moltbot service definition
- Cloudflare Tunnel configuration commented out
- Different volume naming conventions (`CD_*_DATA` vs `cd-vol-*`)

**Replacement:** `COREDIRECTIVE_ENGINE/`

**Reason for Deprecation:** Naming convention mismatch with production deployment standards. All production deployments migrated to hyphen-based naming for consistency with Docker/Kubernetes conventions.

---

### 2. old_workflows/
**Status:** Deprecated as of 2026-01-30

**Description:** n8n workflow JSON files using deprecated Qwen 2.5 model references.

**Reason for Deprecation:** System now uses Qwen 3 8B quantized model exclusively. Old workflow files would fail if executed because Qwen 2.5 models are not installed on the production Ollama instance.

**Replacement:** All workflow files in `COREDIRECTIVE_ENGINE/` have been updated to use `qwen3:8b-instruct-q4_K_M`.

---

## Warning

⚠️ **DO NOT USE FILES IN THIS DIRECTORY FOR NEW DEPLOYMENTS**

Files in this directory are kept solely for historical reference and comparison purposes. They are not maintained and may contain outdated configurations, security vulnerabilities, or incompatible dependencies.

For current production deployment configurations, always refer to:
- **Docker Compose:** `COREDIRECTIVE_ENGINE/docker-compose.yaml`
- **Environment Template:** `COREDIRECTIVE_ENGINE/.env.template`
- **Workflows:** `COREDIRECTIVE_ENGINE/workflow_*.json`

---

## Deprecation History

See [CHANGELOG_DEPRECATIONS.md](CHANGELOG_DEPRECATIONS.md) for full deprecation history and migration notes.

---

**Maintained By:** Emmanuel Tigoue
**Project:** CoreDirective Automation Engine (Operation Nuclear)
