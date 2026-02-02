# CD_ENGINE_MASTER (LEGACY - DO NOT USE)

**Status:** DEPRECATED as of 2026-01-29
**Replacement:** Use `../COREDIRECTIVE_ENGINE/` instead

---

## ⚠️ IMPORTANT NOTICE

This directory contains an older version of the Docker Compose configuration
with different naming conventions and service definitions.

**ALL PRODUCTION DEPLOYMENTS NOW USE `COREDIRECTIVE_ENGINE/`**

---

## Key Differences from COREDIRECTIVE_ENGINE

| Aspect | CD_ENGINE_MASTER (Legacy) | COREDIRECTIVE_ENGINE (Current) |
|--------|---------------------------|-------------------------------|
| **Service Naming** | Underscore (cd_postgres) | Hyphen (cd-service-db) |
| **Container Names** | cd_postgres, cd_n8n, cd_brain_ollama | cd-service-db, cd-service-n8n, cd-service-ollama |
| **Network CIDR** | 172.25.0.0/16 (hardcoded) | Default bridge (no CIDR) |
| **Volume Naming** | CD_DB_DATA, CD_N8N_DATA | CD_VOL_POSTGRES, CD_VOL_N8N |
| **Moltbot Service** | Not included | Included (commented, ready to enable) |
| **Cloudflare Tunnel** | Commented out | Active service definition |
| **Labels** | Includes component/environment labels | No labels (cleaner) |
| **Data Pruning** | N8N_EXECUTIONS_DATA_PRUNE enabled | Not configured |

---

## Migration Complete

All production infrastructure has been migrated to the newer COREDIRECTIVE_ENGINE configuration:

- ✅ Consistent naming conventions (`cd-service-*`)
- ✅ Cloudflare Tunnel integrated
- ✅ Moltbot service prepared (awaiting source code)
- ✅ Simplified configuration (no unnecessary labels)
- ✅ SELinux compliance (`:z` volume flags)
- ✅ Health checks for PostgreSQL

---

## Why This Directory Exists

This directory is kept for:
1. **Historical reference** - Shows the evolution of the stack architecture
2. **Backup configuration** - In case rollback is needed (unlikely)
3. **Documentation** - Demonstrates the refactoring decisions made

---

## If You Need To Use This

**Don't.** Seriously.

If you absolutely must reference this configuration:
1. Note the naming differences above
2. Understand you'll have conflicts if both engines run on same host (network CIDR collision)
3. You'll be responsible for maintaining two separate configurations

**Instead:** Contribute improvements to `COREDIRECTIVE_ENGINE/`

---

## Next Steps

If you're seeing this README, you're in the wrong directory.

```bash
cd ../COREDIRECTIVE_ENGINE/
```

For deployment guidance, see:
- `../docs/ADHD_Runbook.md` - Simple operational guide
- `../docs/TERRAFORM_DEPLOYMENT_GUIDE.md` - Complete deployment walkthrough
- `../DEPLOYMENT_READINESS_CHECKLIST.md` - Pre-flight checks

---

**Questions?** Check the comprehensive documentation in `../docs/`

**Last Updated:** 2026-01-29
