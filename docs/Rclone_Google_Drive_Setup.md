# Rclone + Google Drive Integration: CD-AE Content Engine Mount

**Purpose:** Link your 2TB Google Drive to the CD-AE instance for automated content processing  
**OS Target:** Amazon Linux 2023 / RHEL 9.x  
**Date:** January 29, 2026  

---

## Why Google Drive + CD-AE?

### The 80% Leverage Point

**Without Rclone:**
- You manually download videos from Google Drive
- Transfer them to EC2 via SCP (slow, manual)
- Wait for processing
- Upload results back to Drive
- **Result:** Hours of manual file management per week

**With Rclone Mount:**
- Video files live in Google Drive (infinite backup)
- n8n sees them as local storage at `/data/media/GDRIVE`
- Qwen 3 (7.5GB) can process them directly
- Results auto-sync back to Drive
- **Result:** 100% automated, zero manual transfers

### Use Cases

1. **Content Factory:** Raw 4K YouTube footage → n8n → AI summarization → scripts → uploads
2. **Lead Enrichment:** Company 10-K PDFs on Drive → Qwen 3 → structured analysis → Notion
3. **Business Versioning:** Cyber-Squire OS snapshots → Drive → disaster recovery
4. **Dataset Scaling:** Health/finance data on Drive → Qwen 3 parsing → video scripts

---

## Step 1: Install Rclone on RHEL/Amazon Linux

```bash
sudo dnf install rclone -y
```

**Verify Installation:**
```bash
rclone version
```

**Expected Output:**
```
rclone v1.x.x
- os/arch: linux/amd64
- go version: go1.22
```

---

## Step 2: Configure Google Drive Connection

### Initialize Rclone Config

```bash
rclone config
```

**Follow the prompts:**

```
No remotes found - make new one
n) New remote
s) Set configuration password
q) Quit config

n

name> gdrive
```

**Storage Type:**

```
Type of storage to configure.

Choose a number from below, or type in your own value
...
15 / Google Drive
   "drive"
...

Storage> drive
```

**Google Application Client ID:**

```
Google Application Client ID.
Press Enter to use default?

client_id> [Press Enter for default]
```

**Google Application Client Secret:**

```
Google Application Client Secret.
Press Enter to use default?

client_secret> [Press Enter for default]
```

**Scope:**

```
Scope that rclone should use when requesting access from Google Drive.
Choose a number from below:
1 / Full access all files
2 / Read-only all files (except Application Data Folder)
...

scope> 1
```

**Service Account:**

```
Use service account?
y) Yes
n) No (default)

service_account_file> [Press Enter - no service account]
```

**Edit Advanced Config:**

```
Edit advanced config?
y) Yes
n) No (default)

edit_advanced_config> n
```

**Use Web Browser to Authenticate:**

```
Use auto config?
y) Yes (default)
n) No

auto_config> y
```

**Browser will open.** Log in with your Google account and authorize rclone.

**After Authorization:**

```
Name: gdrive
Type: drive
Client ID: [redacted]
Client Secret: [redacted]
...

Is this ok?
y) Yes this is OK (default)
n) No - start again

y
```

**Create Another Remote?**

```
e) Edit existing remote
n) New remote
d) Delete remote
r) Rename remote
c) Copy remote
s) Set configuration password
q) Quit config

q
```

---

## Step 3: Verify Google Drive Connection

```bash
rclone lsd gdrive:
```

**Expected Output:**
```
          -1 2026-01-29 12:34:56        -1 My Drive
          -1 2026-01-29 12:34:56        -1 Shared drives
```

---

## Step 4: Create Mount Directory

```bash
mkdir -p ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
```

---

## Step 5: Mount Google Drive as Local Storage

### One-Time Mount (Testing)

```bash
rclone mount gdrive: ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
```

**This blocks your terminal.** In a new SSH session, verify it's mounted:

```bash
ls -la ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
```

**Expected:** Shows your Google Drive folders

**Stop mount:** `Ctrl+C` in original terminal

### Persistent Mount (Daemon Mode)

```bash
rclone mount gdrive: ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE \
  --daemon \
  --vfs-cache-mode writes \
  --buffer-size 256M \
  --log-level INFO
```

**Verify it's running:**

```bash
mount | grep rclone
```

**Expected:**
```
gdrive: on /home/ec2-user/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE type fuse.rclone (rw,nosuid,nodev,relatime,...)
```

---

## Step 6: Integration with CD-AE

### n8n Workflow: Detect New Video Files

**Trigger Node:** "Watch Directory"
```
Path: /data/media/GDRIVE/[Your Videos Folder]
File Pattern: *.mp4, *.mov, *.mkv
```

**Process Node:** AI Transcription + Analysis
```
Model: qwen3:8b-instruct-q4_K_M
Prompt: "Analyze this video transcript and generate 10 YouTube titles"
```

**Output Node:** Upload Results Back to Drive
```
Path: /data/media/GDRIVE/[Processed Videos]/[filename_analysis.json]
```

**Result:** Fully automated video-to-script pipeline

---

## Step 7: Persistent Daemon Setup (Systemd Service)

### Create Systemd Service File

```bash
sudo bash -c 'cat > /etc/systemd/system/rclone-gdrive.service << EOF
[Unit]
Description=Rclone Google Drive Mount
After=network.target

[Service]
Type=simple
User=ec2-user
ExecStart=/usr/bin/rclone mount gdrive: /home/ec2-user/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE \
  --daemon \
  --vfs-cache-mode writes \
  --buffer-size 256M \
  --log-level INFO \
  --log-file /home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS/rclone.log
ExecStop=/bin/fusermount -u /home/ec2-user/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF'
```

### Enable and Start Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable rclone-gdrive
sudo systemctl start rclone-gdrive
```

### Verify Service Status

```bash
sudo systemctl status rclone-gdrive
```

**Expected:**
```
● rclone-gdrive.service - Rclone Google Drive Mount
   Loaded: loaded (/etc/systemd/system/rclone-gdrive.service; enabled)
   Active: active (running)
```

### View Mount Logs

```bash
tail -f /home/ec2-user/COREDIRECTIVE_ENGINE/CD_BACKUPS/rclone.log
```

---

## Step 8: Troubleshooting Rclone Mount

### Problem: Mount Fails

```bash
# Check if already mounted
mount | grep rclone

# Unmount forcefully
sudo fusermount -u ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE

# Retry mount
rclone mount gdrive: ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE --daemon
```

### Problem: Permission Denied

```bash
# Fix ownership
sudo chown -R ec2-user:ec2-user ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE

# Verify permissions
ls -ld ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE
# Should show: drwxr-xr-x
```

### Problem: Slow File Transfer

**Increase Buffer Size:**

```bash
rclone mount gdrive: ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE \
  --daemon \
  --vfs-cache-mode writes \
  --buffer-size 512M \  # Increased from 256M
  --transfers 4         # Parallel transfers
```

### Problem: Out of Memory

**Reduce VFS Cache:**

```bash
rclone mount gdrive: ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE \
  --daemon \
  --vfs-cache-mode writes \
  --buffer-size 128M \  # Reduced
  --vfs-cache-max-age 2h
```

---

## Step 9: n8n Integration Example

### Workflow: "Auto-Generate Video Scripts from Drive"

**Node 1: Watch Directory**
```
Type: Trigger > Watch Directory
Path: /data/media/GDRIVE/Raw Videos
File Pattern: *.mp4
Interval: 60 seconds
```

**Node 2: Analyze with Qwen 3**
```
Type: AI Agent
Model: qwen3:8b-instruct-q4_K_M
Prompt: "Summarize this video transcript into 3 YouTube titles"
Input: $json.fileName
```

**Node 3: Save Result to Drive**
```
Type: File > Write
Path: /data/media/GDRIVE/Processed/{{ $json.fileName }}_titles.json
Data: {
  "file": "{{ $json.fileName }}",
  "titles": "{{ $json.output }}",
  "timestamp": "{{ now() }}"
}
```

**Node 4: Slack Notification**
```
Type: Slack
Message: "✅ Processed {{ $json.fileName }}"
Channel: #content-factory
```

---

## Performance Benchmarks (Rclone on t3.xlarge)

```
File Transfer Speed (Google Drive → Local):
- Small files (< 10MB): ~20-30 MB/s
- Large files (100-500MB): ~10-15 MB/s
- 4K Video (5GB): ~12 MB/s (6-7 minutes transfer)

Cache Behavior (--vfs-cache-mode writes):
- First read: From Google Drive (~1-2s latency)
- Subsequent reads: From local cache (~100ms)
- Write-through: Immediate disk, async cloud sync

Concurrent Transfer Capacity:
- 1 transfer: ~15 MB/s
- 4 transfers: ~8-10 MB/s each (--transfers 4)
- Optimal for CD-AE: --transfers 2 (balance stability)
```

---

## Memory Impact: Rclone + Docker Stack

```
Docker Containers:
  - cd-db: 4GB (PostgreSQL)
  - cd-n8n: 2GB (n8n)
  - cd-ollama: 7.5GB (Qwen 3)
  
Rclone Mount:
  - Base: ~50-100MB
  - VFS Cache: ~500MB (with --buffer-size 256M)
  
System Overhead:
  - RHEL OS: 1.5GB
  - Free: ~1GB

Total Used: 15.5-15.8GB / 16GB ✓
```

---

## Automation Recipe: Daily Backup to Drive

### Cron Job: Backup PostgreSQL to Drive

```bash
# Add to crontab
crontab -e

# Paste this line:
0 2 * * * docker exec cd-db pg_dump -U cd_admin -d cd_automation_db -Fc | rclone rcat gdrive:Backups/cd_automation_$(date +\%Y\%m\%d).dump
```

**What happens:**
1. Every day at 02:00 UTC
2. PostgreSQL dumps database to stdout
3. Rclone pipes it directly to Google Drive (`Backups` folder)
4. No local disk usage
5. Automatic versioning on Drive (30-day retention)

---

## Success Checklist

- [ ] Rclone installed (`rclone version` works)
- [ ] Google Drive authenticated (`rclone lsd gdrive:`)
- [ ] Mount directory created (`~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE`)
- [ ] Test mount works (`rclone mount` + verify files visible)
- [ ] Systemd service created and enabled
- [ ] Service survives EC2 restart (`sudo systemctl status rclone-gdrive`)
- [ ] n8n can read files from `/data/media/GDRIVE`
- [ ] Cron backup working (check Drive for daily dumps)

---

## Advanced: Selective Sync (If Your Drive is Huge)

### Mount Only Specific Folders

```bash
# Instead of mounting entire drive, mount just one folder
rclone mount "gdrive:COREDIRECTIVE_ENGINE" ~/COREDIRECTIVE_ENGINE/CD_MEDIA_VAULT/GDRIVE \
  --daemon \
  --vfs-cache-mode writes \
  --buffer-size 256M
```

**Benefit:** Faster indexing, lower memory footprint

---

## Next: Content Automation

With Rclone mounted, you now have:
- **Infinite storage** (2TB Google Drive)
- **Local access** (files appear in `/data/media/GDRIVE`)
- **Automated sync** (changes both ways)
- **AI processing** (Qwen 3 can read/analyze directly)
- **n8n orchestration** (trigger workflows on file changes)

This is the **80% leverage point** for Operation Nuclear expansion into content production.

---

**Version:** 1.0.0  
**Last Updated:** January 29, 2026  
**Maintained By:** Emmanuel Tigoue  
**Next Review:** April 29, 2026
