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

# --- 2. INSTALL BORE ---
echo "📥 Installing Bore..."
curl -Ls https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz | tar zx -C .
chmod +x ./bore

# --- 3. START TUNNEL ---
echo "🌐 Starting Bore Tunnel..."
# This opens a tunnel to port 25565. 
# It will give you a random port on bore.pub (e.g., bore.pub:12345)
./bore local 25565 --to bore.pub > bore.log 2>&1 &

# --- 4. WAIT FOR URL & SEND TO DISCORD ---
sleep 5
ADDRESS=$(grep -oE "bore.pub:[0-9]+" bore.log | head -n 1)

if [ -n "$ADDRESS" ]; then
    IP="wss://$ADDRESS"
    echo "✅ Server Live at: $IP"
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚀 **Server Online!**\\n🔗 **IP:** \`$IP\`\"}" "$DISCORD_WEBHOOK"
else
    echo "❌ Failed to get Bore address. Check bore.log"
fi

# --- 4. 4-HOUR TIMER WITH 30s COUNTDOWN ---
(
  sleep 1770 # Wait until 6:59:30 PM IST   14370
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
git add .
git commit -m "Automated Save: $(date)" || echo "No changes to save"
git push origin main
