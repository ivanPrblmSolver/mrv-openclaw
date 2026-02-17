#!/bin/bash
set -e

echo "=== OpenClaw VPS Setup ==="

# Create directories
mkdir -p /opt/openclaw/{config,workspace,logs}
chown -R 1000:1000 /opt/openclaw
chmod 700 /opt/openclaw/config

# Create .env from template if needed
if [ ! -f .env ]; then
  cp .env.prod.example .env
  echo "Created .env from template."
fi

echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "1. Edit .env with your OPENCLAW_GATEWAY_TOKEN and TELEGRAM_BOT_TOKEN"
echo "2. docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 -t openclaw:local ."
echo "3. docker compose -f docker-compose.prod.yml up -d"
echo "4. Run the interactive wizard:"
echo "   docker compose -f docker-compose.prod.yml run --rm -it openclaw-cli onboard"
