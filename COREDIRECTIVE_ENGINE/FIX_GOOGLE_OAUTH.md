# Fix Google OAuth Callback (400 Error Resolution)

## The Problem

Google's OAuth security servers **cannot reach `localhost`**. When you use `http://localhost:5678` as your n8n URL, Google tries to send the authorization code back to `localhost` and hits a wall.

Since you're using **Cloudflare Tunnel**, n8n must identify itself as `https://n8n.yourdomain.com`, not localhost.

---

## The Solution (3 Steps)

### Step 1: Restart n8n with Correct Configuration

The docker-compose.yaml has been updated with correct environment variables:

```bash
cd /Users/et/cyber-squire-ops/COREDIRECTIVE_ENGINE
docker compose down
docker compose up -d
```

Wait 30 seconds for n8n to fully restart.

---

### Step 2: Update Google Cloud Console

#### 2.1 Navigate to OAuth Settings
```
https://console.cloud.google.com → APIs & Services → Credentials
```

#### 2.2 Edit OAuth Client
Find: `213586018316-c6iik0v8bc6qiknnh85i967gpscfbhkb`
Click: Edit

#### 2.3 Update Authorized Redirect URIs

**Remove:** Any `localhost` entries

**Add exactly this:**
```
https://n8n.yourdomain.com/rest/oauth2-credential/callback
```

**Save** and wait 60-90 seconds for propagation.

---

### Step 3: Reconnect in n8n

1. Go to `https://n8n.yourdomain.com`
2. Credentials → "Google OAuth CoreDirective"
3. Verify redirect URL shows `https://n8n.yourdomain.com/...` (not localhost)
4. Click "Sign in with Google"
5. If prompted "This app isn't verified" → Advanced → Go to n8n (unsafe)
6. Grant permissions

---

## Verification Checklist

✅ docker-compose.yaml updated with `N8N_HOST=https://n8n.yourdomain.com`
✅ Docker restarted
✅ Google Cloud Console redirect URI: `https://n8n.yourdomain.com/rest/oauth2-credential/callback`
✅ n8n shows correct public URL
✅ OAuth connection successful (green checkmark)

**OAuth is now configured correctly.** ✅
