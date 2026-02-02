#!/bin/bash
# Quick health check for CoreDirective stack
set -euo pipefail

cd "$(dirname "$0")"

# Check Docker Compose services
if ! docker compose ps | grep -q 'Up'; then
  echo "[ERROR] One or more containers are not running."
  docker compose ps
  exit 1
fi

echo "[INFO] All containers are running."

echo "[INFO] Checking logs for errors/warnings..."
for svc in cd-service-db cd-service-n8n cd-service-ollama cd-service-moltbot tunnel-cyber-squire; do
  if docker ps --format '{{.Names}}' | grep -q "$svc"; then
    echo "--- $svc logs (last 30 lines) ---"
    docker logs --tail=30 "$svc" | grep -iE 'error|fail|warn' || echo "No errors/warnings detected."
  fi
done

echo "[INFO] Testing n8n → Postgres connectivity..."
docker exec cd-service-n8n bash -c 'PGPASSWORD="$DB_POSTGRESDB_PASSWORD" psql -h "$DB_POSTGRESDB_HOST" -U "$DB_POSTGRESDB_USER" -d "$DB_POSTGRESDB_DATABASE" -c "\l"' || echo "[WARN] n8n could not connect to Postgres."

echo "[INFO] Testing n8n → Ollama connectivity..."
docker exec cd-service-n8n curl -sSf http://cd-service-ollama:11434/api/tags && echo "[OK] n8n can reach Ollama." || echo "[WARN] n8n cannot reach Ollama."

echo "[INFO] Testing Moltbot → n8n and Ollama connectivity..."
docker exec cd-service-moltbot curl -sSf http://cd-service-n8n:5678/healthz && echo "[OK] Moltbot can reach n8n." || echo "[WARN] Moltbot cannot reach n8n."
docker exec cd-service-moltbot curl -sSf http://cd-service-ollama:11434/api/tags && echo "[OK] Moltbot can reach Ollama." || echo "[WARN] Moltbot cannot reach Ollama."

echo "[INFO] Cloudflare Tunnel status:"
docker logs --tail=20 tunnel-cyber-squire | grep -iE 'route|ready|error|fail|warn' || echo "No tunnel errors/warnings."

echo "[DONE] Health check complete."
