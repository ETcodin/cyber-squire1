#!/bin/bash
# CoreDirective RHEL+Docker Hardening & Startup Script
# Usage: sudo ./cdae-init.sh
set -euo pipefail

# 1. Remove Podman/Buildah to prevent Docker socket conflicts
echo "[1/7] Removing Podman and Buildah (if present)..."
sudo dnf remove -y podman buildah || true

# 2. Install Docker CE repo and engine
echo "[2/7] Installing Docker CE..."
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. Enable/start Docker and add user to docker group
echo "[3/7] Enabling Docker service..."
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
echo "[INFO] You must log out and back in to apply docker group changes."

# 4. Create required directories
echo "[4/7] Creating persistent volumes..."
mkdir -p CD_VOL_POSTGRES CD_VOL_N8N CD_VOL_OLLAMA CD_VOL_MOLT media

# 5. Apply SELinux relabel for all project files
echo "[5/7] Relabeling files for SELinux..."
sudo chcon -Rt svirt_sandbox_file_t .

# 6. Build Moltbot (if present)
if [ -d "moltbot" ]; then
  echo "[6/7] Building Moltbot image..."
  cd moltbot && docker compose build && cd ..
else
  echo "[6/7] Skipping Moltbot build (moltbot directory not found)"
fi

# 7. Start the stack
echo "[7/7] Starting Docker Compose stack..."
docker compose up -d

echo "[DONE] All services started. Run 'docker ps' and 'docker-compose logs -f --tail=50' to verify health."
