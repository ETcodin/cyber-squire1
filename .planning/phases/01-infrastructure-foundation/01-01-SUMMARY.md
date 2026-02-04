# Plan 01-01: Ollama Keep-Alive Configuration

## Objective
Configure Ollama Docker container to keep models loaded for 24 hours, preventing cold start delays.

## Status
COMPLETED - 2026-02-04

## Tasks Completed

### 1. Update docker-compose.yaml Configuration
- File: `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/docker-compose.yaml`
- Change: Added `OLLAMA_KEEP_ALIVE=24h` to cd-service-ollama environment section
- Commit: 29ee8eb - "Configure Ollama to keep models loaded for 24 hours"

### 2. Deploy Configuration to EC2
- Target: ec2-user@54.234.155.244
- Actions:
  - Uploaded updated docker-compose.yaml via SCP
  - Restarted cd-service-ollama container with `docker compose up -d`
  - Container recreated and started successfully

## Verification Results

### Local Verification
```bash
$ grep "OLLAMA_KEEP_ALIVE=24h" COREDIRECTIVE_ENGINE/docker-compose.yaml
      - OLLAMA_KEEP_ALIVE=24h
```

### Remote Verification (EC2)
```bash
$ docker exec cd-service-ollama env | grep OLLAMA_KEEP_ALIVE
OLLAMA_KEEP_ALIVE=24h
```

## Impact
- Models will remain in memory for 24 hours after last use
- Eliminates cold start delays for frequent model requests
- Improves response time for n8n workflows using Ollama
- Memory footprint: Qwen 3 8B (~7.5GB) will stay resident

## Next Steps
- Monitor memory usage on t3.xlarge instance (16GB total)
- Adjust keep-alive duration if needed based on usage patterns
- Document in operational runbook

## Files Modified
- `/Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE/docker-compose.yaml`

## Git Commit
- Hash: 29ee8eb
- Message: "Configure Ollama to keep models loaded for 24 hours"
