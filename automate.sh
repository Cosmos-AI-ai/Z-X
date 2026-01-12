#!/bin/bash

# --- 1. SETUP ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    # Replace any existing token value with the secret from GitHub
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
else
    echo "⚠️ Warning: EssentialsDiscord config not found at $CONFIG_PATH"
fi


# --- 2. INSTALL CLOUDFLARE ---
echo "📥 Installing Cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
chmod +x cloudflared

# --- 3. START TUNNEL ---
echo "🌐 Starting Permanent Tunnel..."
# This starts the tunnel in the background so the script can keep moving
./cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" > tunnel.log 2>&1 &

# --- 4. NOTIFY DISCORD ---
echo "⏳ Waiting for connection..."
sleep 10 # Increased to 10s to give the tunnel more time to handshake

# Use the domain you set in GitHub Secrets
# This line tells the script to use the domain from your GitHub Secrets
DOMAIN_NAME="${MY_DOMAIN}"
IP="wss://$DOMAIN_NAME"

echo "✅ Server Live at: $IP"
curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚀 **Server Online (Permanent Domain)!**\\n🔗 **IP:** \`$IP\`\\n⏰ **Status:** Online for 4 hours.\"}" "$DISCORD_WEBHOOK"
# --- 4. 4-HOUR TIMER WITH 30s COUNTDOWN ---
(
  sleep 14370 # Wait until 6:59:30 PM IST   14370
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds! Saving world..." > server_input
    sleep 1
  done
  echo "stop" > server_input
) &

# --- 5. START SERVER ---
tail -f server_input | bash ./run.sh

# --- 6. PUSH BACK TO GITHUB ---
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

# 1. Stage everything
git add .

# 2. Specifically unstage the config file so it won't be committed
git reset "$CONFIG_PATH"

# 3. Commit and push the rest
git commit -m "Automated Save: $(date)" || echo "No changes to save"
git push origin main
