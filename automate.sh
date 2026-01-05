#!/bin/bash

# --- 1. CONFIGURATION ---
# We use the variable from your GitHub Secrets
# If it's empty, the script will show a warning
if [ -z "$DISCORD_WEBHOOK" ]; then
    echo "⚠️ WARNING: DISCORD_WEBHOOK secret is not set!"
fi

# --- 2. SETUP ENVIRONMENT ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
fi

rm -f server_input
mkfifo server_input

# --- 3. START LIVE CONSOLE (tmate) ---
echo "📦 Installing tmate..."
sudo apt-get update && sudo apt-get install -y tmate > /dev/null 2>&1
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait tmate-ready
CONSOLE_URL=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')

echo "************************************************"
echo "🛠️ OWNER CONSOLE URL: $CONSOLE_URL"
echo "************************************************"

# --- 4. START LOCALHOST.RUN TUNNEL ---
echo "🚀 Starting tunnel via localhost.run..."
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=60 \
    -R 80:localhost:25565 \
    lhr.life > tunnel.log 2>&1 &

# Extract URL (Wait up to 30 seconds)
ADDRESS=""
for i in {1..15}; do
    # This grep is more robust: it removes http:// if present
    ADDRESS=$(grep -oE "https?://[a-zA-Z0-9.-]+\.lhr\.life" tunnel.log | sed -E 's/https?:\/\///' | head -n 1)
    if [ -n "$ADDRESS" ]; then break; fi
    sleep 2
done

# --- 5. DISCORD NOTIFICATION ---
if [ -z "$ADDRESS" ]; then
    ERROR_DATA=$(tail -n 5 tunnel.log)
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"❌ **Tunnel Failed**\n\`\`\`$ERROR_DATA\`\`\`\"}" "$DISCORD_WEBHOOK"
else
    WSS_ADDRESS="wss://$ADDRESS"
    PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "Z X Server Online!",
    "description": "The tunnel is active via localhost.run",
    "color": 3066993,
    "fields": [
      { "name": "🔗 WebSocket IP", "value": "\`$WSS_ADDRESS\`" },
    ]
  }]
}
EOF
)
    curl -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$DISCORD_WEBHOOK"
fi

# --- 6. START MINECRAFT ---
echo "Starting Minecraft..."
# Added a small delay to ensure the pipe is ready
sleep 2
tail -f server_input | bash ./run.sh &
SERVER_PID=$!

# --- 7. SHUTDOWN & AUTO-SAVE ---
# 13800 seconds = ~3.8 hours
sleep 13800
echo "say Server is saving and restarting..."
