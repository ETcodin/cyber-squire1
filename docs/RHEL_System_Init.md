# RHEL/Amazon Linux 2023 System Initialization Guide

**Target Environment:** AWS EC2 t3.xlarge (Amazon Linux 2023 / RHEL 9.x)  
**Date:** January 29, 2026  
**Version:** 1.0.0-RHEL  

---

## Phase 1: System Preparation

### Step 1: Update the System
```bash
sudo dnf update -y
```

### Step 2: Install Docker
```bash
sudo dnf install docker -y
```

### Step 3: Start and Enable Docker Service
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Step 4: Add ec2-user to Docker Group (No More sudo)
```bash
sudo usermod -aG docker ec2-user
```
**Important:** Log out and back in for group membership to take effect
```bash
exit
# Reconnect SSH session
ssh -i cyber-squire-key.pem ec2-user@<elastic-ip>
```

### Step 5: Install Docker Compose (Modern V2 Plugin)
```bash
sudo dnf install docker-compose-plugin -y
```

### Step 6: Verify Installation
```bash
docker version
docker compose version
```

**Expected Output:**
```
Docker version 25.0.x, build xxxxxxx
Docker Compose version v2.x.x
```

---

## Phase 2: CoreDirective Engine Deployment

### Step 1: Create Project Directory
```bash
mkdir -p ~/COREDIRECTIVE_ENGINE/{cd-db-data,cd-n8n-data,cd-ollama-data,CD_BACKUPS,CD_MEDIA_VAULT}
cd ~/COREDIRECTIVE_ENGINE
```

### Step 2: Create .env File from Template
```bash
cat > .env << 'EOF'
# --- DATABASE SECRETS ---
CD_DB_USER=cd_admin
CD_DB_PASS=REPLACE_WITH_SECURE_PASSWORD
CD_DB_NAME=cd_automation_db

# --- N8N SECURITY ---
CD_N8N_KEY=GENERATED_32_CHAR_STRING
CD_N8N_JWT=ANOTHER_RANDOM_STRING
CD_N8N_USER=admin@yourdomain.com
CD_N8N_PASS=REPLACE_WITH_N8N_PASSWORD

# --- OLLAMA CONFIGURATION ---
CD_OLLAMA_HOST=cd-service-ollama
CD_OLLAMA_PORT=11434
CD_OLLAMA_MODEL=qwen3:8b-instruct-q4_K_M

# --- STORAGE ---
CD_STORAGE_PATH=/home/ec2-user/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT
CD_BACKUP_PATH=/home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS
EOF
```

### Step 3: Generate Secure Passwords
```bash
# Generate password 1 (CD_DB_PASS)
openssl rand -base64 32

# Generate password 2 (CD_N8N_KEY)
openssl rand -base64 32

# Generate password 3 (CD_N8N_JWT)
openssl rand -base64 32
```

**Edit .env and replace placeholders:**
```bash
nano .env
```
- Replace `REPLACE_WITH_SECURE_PASSWORD` with first generated password
- Replace `GENERATED_32_CHAR_STRING` with second generated password
- Replace `ANOTHER_RANDOM_STRING` with third generated password
- Save: `Ctrl+X`, then `Y`, then `Enter`

### Step 4: Copy docker-compose.yaml
```bash
cat > docker-compose.yaml << 'EOF'
version: '3.8'

services:
  cd-db:
    image: postgres:16-alpine
    container_name: cd-db
    restart: always
    deploy:
      resources:
        limits:
          memory: 4G
    environment:
      POSTGRES_USER: ${CD_DB_USER}
      POSTGRES_PASSWORD: ${CD_DB_PASS}
      POSTGRES_DB: ${CD_DB_NAME}
    volumes:
      - ./cd-db-data:/var/lib/postgresql/data
    networks:
      - cd-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${CD_DB_USER} -d ${CD_DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

  cd-n8n:
    image: n8nio/n8n:latest
    container_name: cd-n8n
    restart: always
    ports:
      - "5678:5678"
    deploy:
      resources:
        limits:
          memory: 2G
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=cd-db
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${CD_DB_NAME}
      - DB_POSTGRESDB_USER=${CD_DB_USER}
      - DB_POSTGRESDB_PASSWORD=${CD_DB_PASS}
      - N8N_ENCRYPTION_KEY=${CD_N8N_KEY}
      - N8N_USER_MANAGEMENT_JWT_SECRET=${CD_N8N_JWT}
    volumes:
      - ./cd-n8n-data:/home/node/.n8n
      - /home/ec2-user/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT:/data/media
    depends_on:
      cd-db:
        condition: service_healthy
    networks:
      - cd-net

  cd-ollama:
    image: ollama/ollama:latest
    container_name: cd-ollama
    restart: always
    ports:
      - "11434:11434"
    deploy:
      resources:
        limits:
          memory: 7.5G
    volumes:
      - ./cd-ollama-data:/root/.ollama
    networks:
      - cd-net

networks:
  cd-net:
    driver: bridge
EOF
```

### Step 5: Launch the Stack
```bash
docker compose up -d
```

### Step 6: Verify Containers are Running
```bash
docker compose ps
```

**Expected Output:**
```
CONTAINER ID   IMAGE                    COMMAND                  STATUS
...            postgres:16-alpine       "docker-entrypoint..."   Up (healthy)
...            n8nio/n8n:latest         "node /dist/index..."    Up
...            ollama/ollama:latest     "ollama serve"           Up
```

### Step 7: Wait 2 Minutes for Database Initialization
```bash
sleep 120
```

### Step 8: Download Qwen 3 Model (Takes 10-15 Minutes)
```bash
docker exec -it cd-ollama ollama pull qwen3:8b-instruct-q4_K_M
```

**Progress Indicator:**
```
Pulling from library
Downloading model...
[=========>     ] 45%  (downloading 2.1GB/4.7GB)
...
Downloaded successfully
```

### Step 9: Verify Qwen 3 is Available
```bash
docker exec cd-ollama ollama list
```

**Expected:**
```
NAME                          ID              SIZE
qwen3:8b-instruct-q4_K_M      abcd1234        4.7GB
```

### Step 10: Configure Google Drive Mount (Optional - For Content Automation)

**Install Rclone:**
```bash
sudo dnf install rclone -y
```

**Create mount directory:**
```bash
mkdir -p ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
```

**Configure Google Drive connection:**
```bash
rclone config
# Follow prompts: name=gdrive, type=drive, authenticate with browser
```

**Mount as daemon:**
```bash
rclone mount gdrive: ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE \
  --daemon \
  --vfs-cache-mode writes \
  --buffer-size 256M
```

**Verify mount:**
```bash
ls ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
# Should show your Google Drive folders
```

**For persistent mount on EC2 restart:**
See [Rclone_Google_Drive_Setup.md](Rclone_Google_Drive_Setup.md) for systemd service setup

---

## Phase 3: Access n8n

### Step 1: Open Browser
Navigate to: `http://<elastic-ip>:5678`

### Step 2: Create Admin Account (First Login)
- Email: `admin@yourdomain.com` (or your email)
- Password: Use the `CD_N8N_PASS` from .env

### Step 3: Verify Database Connection
- Click **Settings** (gear icon)
- Click **About**
- Verify: "✓ PostgreSQL" is shown


### Step 1: Install Cloudflare CLI
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64.rpm -o cloudflared.rpm
sudo dnf install ./cloudflared.rpm -y
rm cloudflared.rpm
```

### Step 2: Authenticate
```bash
cloudflared tunnel login
```
(Browser will open for authentication)

### Step 3: Create Tunnel
```bash
cloudflared tunnel create cd-engine-tunnel
```

### Step 4: Route DNS (Replace with your domain)
```bash
cloudflared tunnel route dns cd-engine-tunnel n8n.yourdomain.com
```

### Step 5: Run Tunnel
```bash
cloudflared tunnel run cd-engine-tunnel
```

**Expected Output:**
```
2026-01-29 12:34:56 INF Starting tunnel...
2026-01-29 12:34:56 INF Tunnel connected
```

### Step 6: Access from Browser
In a new terminal (tunnel keeps running):
```
Open: https://n8n.yourdomain.com
```

**No open ports. No public IP exposure. Only you can access it.** ✅

---

## Phase 5: Operation Nuclear Configuration

### Step 1: Create Notion Integration
1. In Notion, create a database called "Operation Nuclear"
2. Add columns: Company Name, CEO Name, Email, Status, Notes
3. Get Notion API key from notion.so/my-integrations

### Step 2: Create n8n Workflow
1. In n8n UI, click **"Create New Workflow"**
2. Add **Notion Trigger**: Watch for new entries in Operation Nuclear database
3. Add **AI Agent Node**: Call Qwen 3 to analyze and draft pitch
4. Add **Slack Notification**: Send draft for approval
5. Add **Gmail Send**: On approval, send email
6. Add **Notion Update**: Mark as "Sent"

### Step 3: Test with Sample Company
1. Add one company to Notion
2. Watch n8n generate personalized pitch
3. Approve and send

---

## Memory Allocation & Monitoring

### Safe Operating Ranges (16GB t3.xlarge)
```
cd-service-ollama: < 7.5 GB (Qwen 3 8B + headroom)
cd-service-db:    < 4.0 GB
cd-service-n8n:   < 2.0 GB
OS/Docker:        2.5 GB (fixed)
Total:            16 GB (no swapping)
```

### Monitor Memory in Real-Time
```bash
watch -n 1 'docker stats --no-stream'
```

### If Ollama Exceeds 7.5GB
```bash
docker compose restart cd-service-ollama
# Wait 2 minutes for model reload
```

---

## Troubleshooting (RHEL-Specific)

### Problem: "docker: command not found"
**Solution:**
```bash
# Add ec2-user to docker group and log out/in
sudo usermod -aG docker ec2-user
exit
# Reconnect SSH
```

### Problem: "permission denied while trying to connect to Docker daemon"
**Solution:**
```bash
# Verify you're in docker group
groups

# If docker not listed:
sudo usermod -aG docker ec2-user
# Log out and back in
```

### Problem: "Cannot connect to PostgreSQL"
```bash
# Check database health
docker compose logs cd-service-db | tail -20

# Restart database
docker compose restart cd-service-db
```

### Problem: "Out of disk space"
```bash
# Check disk usage
df -h

# Clean old backups
find ~/COREDIRECTIVE_ENGINE/CD_BACKUPS -name "*.dump" -mtime +14 -delete

# Check container images
docker system df
docker system prune -a
```

---

## Quick Reference Commands (RHEL-Specific)

```bash
# View logs
docker compose logs -f --tail=50

# Restart one service
docker compose restart cd-service-ollama

# Restart entire stack
docker compose down && sleep 10 && docker compose up -d

# Check resource usage
docker stats --no-stream

# SSH into PostgreSQL
docker exec -it cd-service-db psql -U cd_admin -d cd_automation_db

# Test Ollama API
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3:8b-instruct-q4_K_M","prompt":"Hello","stream":false}'

# Backup database
docker exec cd-service-db pg_dump -U cd_admin -d cd_automation_db -Fc > backup_$(date +%Y%m%d).dump

# List all volumes
docker volume ls | grep cd-

# Clean up unused data
docker system prune --volumes
```

---

## Success Checklist

- [ ] Docker installed and running
- [ ] ec2-user can run docker commands (no sudo)
- [ ] All 4 containers up and healthy
- [ ] PostgreSQL database accessible
- [ ] n8n accessible at `http://<ip>:5678`
- [ ] Qwen 3 model downloaded and available
- [ ] Ollama API responding at `http://localhost:11434`
- [ ] Cloudflare Tunnel configured (optional)
- [ ] n8n connected to PostgreSQL backend
- [ ] First test workflow created

---

**Version:** 1.0.0-RHEL  
**Last Updated:** January 29, 2026  
**Target:** Amazon Linux 2023 / RHEL 9.x  
**Next Review:** April 29, 2026
