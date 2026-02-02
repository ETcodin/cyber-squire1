# ADHD Runbook: CoreDirective Automation Engine (CD-AE) - Quick Reference

**Purpose:** Simple, jargon-free operational steps for quick recovery and daily management  
**Audience:** Anyone managing the system (no Linux/Docker expertise required)  
**Format:** Copy-paste commands; numbered steps; zero assumptions  
**OS Target:** Amazon Linux 2023 / RHEL 9.x (dnf-based)  

---

## SECTION 1: LAUNCH (First Time Setup)

### Step 1: Connect to Server
```bash
ssh -i cyber-squire-key.pem ec2-user@[YOUR_IP_ADDRESS]
# Note: Amazon Linux uses 'ec2-user', not 'ubuntu'
```

### Step 2: Navigate to Project
```bash
cd /home/ec2-user/COREDIRECTIVE_ENGINE
```

### Step 3: Set Up Passwords
```bash
# Copy template to real file
cp .env.template .env

# Open for editing
nano .env
```
**What to change:**
- Find: `CD_DB_PASS=REPLACE_WITH_SECURE_PASSWORD_32_CHARS`
- Replace with: A random 32-character password (use a password manager)
- Find: `CD_N8N_KEY=GENERATE_RANDOM_32_CHAR_STRING_OPENSSL`
- Replace with: Run this command in a NEW terminal window:
  ```bash
  openssl rand -base64 32
  ```
- Copy the output; paste into .env
- Repeat for `CD_N8N_JWT`
- Save file: Press `Ctrl+X`, then `Y`, then `Enter`

### Step 4: Start Everything
```bash
docker-compose up -d
```
**What happens:** 4 containers start (PostgreSQL, n8n, Ollama, Cloudflare Tunnel)
**Note:** Moltbot service is currently disabled - enable later for automated lead enrichment

### Step 5: Wait 2 Minutes
(Docker pulls images and starts services)

### Step 6: Check Status
```bash
docker-compose ps
```
**Expected output:**
```
cd-service-db        ✓ Up (healthy)
cd-service-n8n       ✓ Up
cd-service-ollama    ✓ Up
```

### Step 7: Download AI Model (This Takes 10-15 Minutes)
```bash
docker exec -it cd-service-ollama ollama pull qwen3:8b-instruct-q4_K_M
```
**What you'll see:**
- "Downloading model..." (watch the progress bar)
- "Downloaded successfully" (when done)

### Step 8: Open n8n
In your browser, go to:
```
http://[YOUR_IP_ADDRESS]:5678
```
**Login:**
- Email: `admin@yourdomain.com`
- Password: (the one you set in .env as CD_N8N_PASS)

### Step 9: Verify Everything Works
In n8n, go to **Settings > About**. You should see:
- Database: ✓ PostgreSQL
- Node count: ✓ 1 (from Notion)

**If you see this, LAUNCH IS COMPLETE.** ✅

---

## SECTION 2: DAILY OPERATIONS

### Check System Health (Every Morning)
```bash
cd /home/ec2-user/COREDIRECTIVE_ENGINE
docker-compose ps
```
**Expected:** All 4 containers show "Up"

### View System Logs (If Something Seems Wrong)
```bash
docker-compose logs -f --tail=50
```
**What to look for:**
- ERROR messages (reds/yellows)
- "Connection refused" (database issue)
- "OOM killed" (out of memory—restart ollama)

### Restart Everything (Nuclear Option)
```bash
docker-compose down
sleep 10
docker-compose up -d
```

### Check Memory Usage
```bash
docker stats --no-stream
```
**Safe ranges:**
- `cd-service-ollama`: < 6.0 GB
- `cd-service-db`: < 4.0 GB
- `cd-service-n8n`: < 2.0 GB

### Monitor n8n Workflows
1. Open: `http://[YOUR_IP]:5678`
2. Click **"Executions"** (top menu)
3. Look for green checkmarks (success) or red X's (failed)
4. Click any failed execution to see error message

---

## SECTION 3: COMMON PROBLEMS & FIXES

### Problem: "n8n won't start" or "Connection refused"

**Diagnosis:**
```bash
docker-compose logs cd-service-n8n | tail -20
```

**Fix:**
```bash
# Restart just n8n
docker-compose restart cd-service-n8n
sleep 5
docker-compose ps
```

---

### Problem: "Ollama is slow" or "System feels sluggish"

**Check memory:**
```bash
docker stats --no-stream | grep cd-service-ollama
```

**If memory > 7.5 GB:**
```bash
docker compose restart cd-service-ollama
# Wait 2 minutes for it to come back
```

---

### Problem: "Can't access n8n" or "Page won't load"

**Check if port is open:**
```bash
docker-compose ps | grep n8n
# Look for: "0.0.0.0:5678->5678/tcp"

# If you see that, but browser still fails:
curl http://localhost:5678
```

**Fix:**
```bash
# Restart n8n
docker-compose restart cd-service-n8n
```

---

### Problem: "Database is locked" or "Too many connections"

**Check database health:**
```bash
docker-compose logs cd-service-db | tail -20
```

**Fix:**
```bash
docker-compose restart cd-service-db
# Wait 30 seconds
docker-compose ps
```

---

### Problem: "Out of disk space"

**Check what's using space:**
```bash
du -sh /home/ec2-user/COREDIRECTIVE_ENGINE/*
```

**Most likely culprit:** Old Ollama models or PostgreSQL backups

**Clean backups older than 14 days:**
```bash
find /home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS -name "*.dump" -mtime +14 -delete
```

**Remove old Ollama images:**
```bash
docker exec cd-service-ollama ollama list
# Then manually delete any you don't need (keep qwen3:8b-instruct-q4_K_M)
```

---

## SECTION 4: BACKUP & RECOVERY

### Manual Backup (Do This Weekly)
```bash
docker exec cd-service-db pg_dump \
  -U cd_admin \
  -d cd_automation_db \
  -Fc > /home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS/backup_$(date +%Y%m%d).dump

# Verify it worked
ls -lh /home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS/
```

### Restore from Backup (If Data Gets Corrupted)
```bash
# Stop n8n (so it doesn't write during restore)
docker compose stop cd-service-n8n

# Find your backup file
ls /home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS/

# Restore (replace DATE with your backup date, e.g., 20260129)
docker exec cd-service-db pg_restore \
  -U cd_admin \
  -d cd_automation_db \
  -v /backups/backup_20260129.dump

# Restart everything
docker compose up -d
```

---

## SECTION 5: ACCESSING FROM OUTSIDE (After Cloudflare Setup)

### Set Up Remote Access (One-Time)

**On your laptop:**
```bash
# Install Cloudflare CLI
brew install cloudflare/cloudflare/cloudflared

# Login (opens browser)
cloudflared tunnel login

# Create tunnel (from your laptop, not EC2)
cloudflared tunnel create cd-engine

# Add route (replace "yourdomain.com" with your domain)
cloudflared tunnel route dns cd-engine n8n.yourdomain.com

# Start tunnel (this stays running)
cloudflared tunnel run cd-engine
```

### Access n8n from Anywhere
```
Open browser: https://n8n.yourdomain.com
```

**That's it.** No open ports on your router. No public IP exposure. Only you can access it (via email OTP).

---

## SECTION 6: OPERATION NUCLEAR WORKFLOW (Creating Your First Outreach Batch)

### Step 1: Add Companies to Notion
1. Open your Notion "Operation Nuclear" database
2. Add 10 company names + CEO names (one row per company)
3. Save

### Step 2: Trigger n8n Workflow
1. Open: `http://[YOUR_IP]:5678`
2. Click **"Workflows"**
3. Find **"operation-nuclear-phase-1"**
4. Click **"Test Workflow"**

### Step 3: Watch It Generate Pitches
- Check **"Executions"** tab
- Watch the AI draft personalized emails (should take 10-20 seconds each)
- Review outputs in Slack/Discord notifications

### Step 4: Approve & Send
- When you get notified, click the approval link
- Review the draft
- Click "Send"
- Email goes to CEO via Gmail

### Step 5: Track Responses
- Monitor Gmail for replies
- n8n logs all sent emails to PostgreSQL
- Review metrics in n8n dashboard

---

## SECTION 7: EMERGENCY CONTACTS & RESOURCES

**If something breaks and you're stuck:**

1. Check logs first:
   ```bash
   docker-compose logs -f --tail=100
   ```

2. Try restart:
   ```bash
   docker-compose down && sleep 10 && docker-compose up -d
   ```

3. If still broken, gather this info:
   ```bash
   # Paste this into a support ticket:
   docker-compose ps
   docker stats --no-stream
   docker-compose logs | tail -50
   ```

---

## SECTION 8: SCHEDULED MAINTENANCE (Monthly Checklist)

**First Sunday of Each Month:**

- [ ] Backup database manually
- [ ] Check disk usage (`du -sh /home/ec2-user/COREDIRECTIVE_ENGINE/*`)
- [ ] Review n8n error logs for patterns
- [ ] Update Docker images: `docker compose pull && docker compose up -d`
- [ ] Verify Ollama model is still healthy: `docker exec cd-service-ollama ollama list`
- [ ] Delete backups older than 30 days
- [ ] Test disaster recovery (restore a backup to staging)

---

## SECTION 9: CRITICAL PASSWORDS & SECRETS (STORE SECURELY)

**Location of secrets:**
```
/home/ec2-user/COREDIRECTIVE_ENGINE/.env
```

**Minimum security:**
- [ ] Store .env in a password manager (1Password, LastPass, Bitwarden)
- [ ] Rotate `CD_DB_PASS` every 90 days
- [ ] Rotate `CD_N8N_KEY` and `CD_N8N_JWT` every 90 days
- [ ] NEVER share .env file via email or Slack
- [ ] NEVER commit .env to git

---

## SECTION 10: SUCCESS CHECKLIST

Once you complete this runbook, verify:

- [ ] EC2 instance running (can SSH in)
- [ ] All 4 Docker containers healthy
- [ ] Ollama model downloaded (Qwen 3 ~4.7GB)
- [ ] n8n accessible at `http://[IP]:5678`
- [ ] PostgreSQL healthcheck passing
- [ ] First Operation Nuclear workflow created
- [ ] 10+ test outreach emails generated
- [ ] At least 1 email sent to real contact
- [ ] Backup created and verified
- [ ] Cloudflare Tunnel configured (optional but recommended)

---

**Last Updated:** January 29, 2026  
**Next Review:** April 29, 2026  
**Version:** 1.0.0 (ADHD-Optimized)
