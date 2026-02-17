# OpenClaw VPS Deployment Guide

This guide walks you through deploying OpenClaw to your Hostinger VPS with Docker, cloudflared tunnel, and Telegram integration.

## Prerequisites

Before starting, ensure you have:
- [ ] SSH access to your Hostinger VPS
- [ ] A Telegram bot token from [@BotFather](https://t.me/BotFather)
- [ ] A Moonshot AI API key
- [ ] Cloudflared already running on your VPS (for your existing web app)
- [ ] Access to your Cloudflare dashboard

---

## Step 1: Push Files to Your Fork

On your local machine, commit and push the deployment files:

```bash
cd /path/to/openclaw
git add docker-compose.prod.yml .env.prod.example deploy/
git commit -m "Add VPS deployment configuration"
git push origin main
```

---

## Step 2: SSH into Your VPS

```bash
ssh root@YOUR_VPS_IP
```

---

## Step 3: Install Docker (if not already installed)

```bash
curl -fsSL https://get.docker.com | sh
docker --version  # Verify installation
```

---

## Step 4: Clone Your Fork

```bash
cd /opt
git clone https://github.com/YOUR_USERNAME/openclaw.git openclaw-repo
cd openclaw-repo
```

---

## Step 5: Run Setup Script

```bash
chmod +x deploy/setup.sh
sudo ./deploy/setup.sh
```

This creates:
- `/opt/openclaw/config/` - Configuration directory
- `/opt/openclaw/workspace/` - Agent workspace
- `/opt/openclaw/logs/` - Log files
- `.env` file from template

---

## Step 6: Configure Secrets

Generate a gateway token:

```bash
openssl rand -hex 32
```

Edit the `.env` file:

```bash
nano .env
```

Fill in your values:

```bash
OPENCLAW_GATEWAY_TOKEN=<paste-generated-token>
TELEGRAM_BOT_TOKEN=<your-bot-token-from-botfather>
MOONSHOT_API_KEY=<your-moonshot-api-key>
```

Save and exit (Ctrl+X, Y, Enter).

---

## Step 7: Build Docker Image

This takes a few minutes (includes Chromium for web browsing):

```bash
docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 -t openclaw:local .
```

---

## Step 8: Start the Gateway

```bash
docker compose -f docker-compose.prod.yml up -d
```

Verify it's running:

```bash
docker ps | grep openclaw
docker compose -f docker-compose.prod.yml logs -f
```

Press Ctrl+C to exit logs.

---

## Step 9: Run the Onboard Wizard

```bash
docker compose -f docker-compose.prod.yml run --rm -it openclaw-cli onboard
```

The wizard will guide you through:

1. **Model Provider Selection**
   - Select "Moonshot AI" or enter your API key when prompted

2. **Gateway Settings**
   - Port: `18789` (default)
   - Bind: `loopback` (for cloudflared access)
   - Auth: `token` (use the token from your .env)

3. **Channels**
   - Enable Telegram when prompted
   - DM policy: `pairing` (recommended for security)

4. **Risk Acknowledgment**
   - Review and accept the security considerations

After the wizard completes, restart the gateway:

```bash
docker compose -f docker-compose.prod.yml restart openclaw-gateway
```

---

## Step 10: Configure Cloudflared Tunnel

Edit your existing cloudflared configuration:

```bash
sudo nano /etc/cloudflared/config.yml
```

Add the OpenClaw route **before** the catch-all rule:

```yaml
tunnel: <your-tunnel-id>
credentials-file: /etc/cloudflared/<tunnel-id>.json

ingress:
  # Your existing web app routes...
  - hostname: your-existing-app.com
    service: http://localhost:3000

  # Add OpenClaw dashboard
  - hostname: jarvis.prblmsolver.com
    service: http://127.0.0.1:18789

  # Catch-all (must be last)
  - service: http_status:404
```

Add DNS route (if not using wildcard DNS):

```bash
cloudflared tunnel route dns <your-tunnel-name> jarvis.prblmsolver.com
```

Restart cloudflared:

```bash
sudo systemctl restart cloudflared
```

Verify the route works:

```bash
curl http://127.0.0.1:18789/health
```

---

## Step 11: Set Up Cloudflare Zero Trust Access

This protects your dashboard so only YOU can access it.

### 11.1 Open Zero Trust Dashboard

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Click **Zero Trust** in the left sidebar
3. If first time, enter a team name (e.g., `prblmsolver`)

### 11.2 Add Login Method

1. Go to **Settings → Authentication**
2. Under **Login methods**, click **Add new**
3. Select **One-time PIN**
   - This sends a verification code to your email
4. Click **Save**

Alternatively, connect Google, GitHub, or another identity provider.

### 11.3 Create Access Application

1. Go to **Access → Applications**
2. Click **Add an application**
3. Select **Self-hosted**
4. Fill in:
   - **Application name**: `OpenClaw Dashboard`
   - **Session Duration**: `24 hours`
   - **Application domain**: `jarvis.prblmsolver.com`
5. Click **Next**

### 11.4 Add Access Policy

1. **Policy name**: `Owner Only`
2. **Action**: `Allow`
3. Under **Configure rules**, click **Add include**
4. Select:
   - **Selector**: `Emails`
   - **Value**: `your-email@example.com`
5. Click **Next**, then **Add application**

### 11.5 Test Access

1. Open `https://jarvis.prblmsolver.com` in your browser
2. You should see Cloudflare's login page
3. Enter your email and the one-time PIN sent to you
4. After authentication, you'll see the OpenClaw dashboard login
5. Enter your gateway token (from `.env`)

---

## Step 12: Approve Telegram Pairing

1. Open Telegram and DM your bot
2. Send any message (e.g., "Hello")
3. The bot will reply with a pairing code

On your VPS, approve the pairing:

```bash
# List pending pairing requests
docker compose -f docker-compose.prod.yml run --rm openclaw-cli pairing list telegram

# Approve your pairing code
docker compose -f docker-compose.prod.yml run --rm openclaw-cli pairing approve telegram <CODE>
```

Now send another message to your bot - it should respond!

---

## Verification Checklist

Run these checks to confirm everything is working:

```bash
# Container running?
docker ps | grep openclaw

# Gateway healthy?
curl http://127.0.0.1:18789/health

# Logs look good?
docker compose -f docker-compose.prod.yml logs --tail 50
```

- [ ] Container is running (`docker ps`)
- [ ] Health check passes (`curl localhost:18789/health`)
- [ ] Dashboard accessible at `https://jarvis.prblmsolver.com`
- [ ] Zero Trust requires authentication
- [ ] Telegram bot responds to messages

---

## Useful Commands

### View Logs
```bash
docker compose -f docker-compose.prod.yml logs -f
```

### Restart Gateway
```bash
docker compose -f docker-compose.prod.yml restart openclaw-gateway
```

### Stop Gateway
```bash
docker compose -f docker-compose.prod.yml down
```

### Run CLI Commands
```bash
docker compose -f docker-compose.prod.yml run --rm openclaw-cli <command>
```

### Update Configuration
```bash
docker compose -f docker-compose.prod.yml run --rm openclaw-cli config set <key> <value>
docker compose -f docker-compose.prod.yml restart openclaw-gateway
```

### Update OpenClaw
```bash
cd /opt/openclaw-repo
git pull
docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 -t openclaw:local .
docker compose -f docker-compose.prod.yml up -d
```

---

## Troubleshooting

### Gateway won't start
```bash
# Check logs for errors
docker compose -f docker-compose.prod.yml logs openclaw-gateway

# Verify .env file exists and has values
cat .env
```

### Can't access dashboard externally
```bash
# Check cloudflared is running
sudo systemctl status cloudflared

# Check tunnel config
cat /etc/cloudflared/config.yml

# Test local access
curl http://127.0.0.1:18789/health
```

### Telegram bot not responding
```bash
# Check channel status
docker compose -f docker-compose.prod.yml run --rm openclaw-cli channels status

# Check if pairing is approved
docker compose -f docker-compose.prod.yml run --rm openclaw-cli pairing list telegram

# Check logs for Telegram errors
docker compose -f docker-compose.prod.yml logs | grep -i telegram
```

### Browser tool not working
```bash
# Verify browser is installed
docker compose -f docker-compose.prod.yml run --rm openclaw-cli browser status
```

---

## Security Notes

1. **Two-layer authentication**: Cloudflare Zero Trust + Gateway token
2. **Loopback binding**: Gateway only accessible via cloudflared, not directly from internet
3. **Non-root container**: Runs as `node` user (uid 1000)
4. **Pairing mode**: New Telegram users must be approved before chatting
5. **No privileged mode**: Standard Docker isolation

---

## Support

- OpenClaw Documentation: Check the `docs/` folder in this repo
- Issues: https://github.com/openclaw/openclaw/issues
