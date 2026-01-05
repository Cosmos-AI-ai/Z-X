#!/bin/bash

# --- 1. SETUP ---
# Ensure SSH keys exist for the tunnel
if [ ! -f ~/.ssh/id_ed25519 ]; then
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
fi

# Create pipe for server input
rm -f server_input && mkfifo server_input

# --- 2. START TUNNEL (Localhost.run) ---
echo "🚀 Requesting default tunnel..."
# We tunnel port 25565 to the web via port 80 (to get SSL for wss://)
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=60 \
    -R 80:localhost:25565 \
    lhr.life > tunnel.log 2>&1 &

# Wait and extract the URL
ADDRESS=""
for i in {1..20}; do
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.lhr\.life" tunnel.log | head -n 1)
    if [ -n "$ADDRESS" ]; then
        echo "✅ URL Found: $ADDRESS"
        break
    fi
    echo "⏳ Waiting for tunnel... ($i/20)"
    sleep 2
done

# --- 3. SEND TO DISCORD ---
if [ -z "$ADDRESS" ]; then
    echo "❌ Tunnel failed. Check tunnel.log"
    # Send error to Discord if possible
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"❌ Tunnel failed to start.\"}" "$DISCORD_WEBHOOK"
else
    WSS_URL="wss://$ADDRESS"
    # Simple JSON payload
    PAYLOAD=$(cat <<EOF
{
  "content": "🛠️ **Eaglercraft Test Online**\n🔗 **WSS IP:** \`$WSS_URL\`\n🌍 **Web:** \`https://$ADDRESS\`"
}
EOF
)
    curl -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$DISCORD_WEBHOOK"
fi

# --- 4. START MINECRAFT ---
echo "Starting Minecraft..."
tail -f server_input | bash ./run.sh
