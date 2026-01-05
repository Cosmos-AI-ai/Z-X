#!/bin/bash

# --- 1. CONFIGURATION ---
# Localhost.run uses subdomains differently, but we can still try to request one
SUBDOMAIN="zx-$RANDOM"
DISCORD_WEBHOOK="YOUR_DISCORD_WEBHOOK_HERE"

# --- 2. SETUP ENVIRONMENT ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
fi

rm -f server_input
mkfifo server_input

# --- 3. START LIVE CONSOLE (tmate) ---
sudo apt-get update && sudo apt-get install -y tmate
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait tmate-ready
CONSOLE_URL=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')

# --- 4. START LOCALHOST.RUN TUNNEL ---
echo "🚀 Starting tunnel via localhost.run..."
# localhost.run uses 'lhr.life' as the host.
# We connect port 80 (web) to your internal 25565
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=60 \
    -R 80:localhost:25565 \
    lhr.life > tunnel.log 2>&1 &

# Extract URL (Wait up to 30 seconds)
ADDRESS=""
for i in {1..15}; do
    # Localhost.run links usually look like: something.lhr.life
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.lhr\.life" tunnel.log | head -n 1)
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
    "title": "🏰 Eaglercraft Server Online!",
    "description": "The tunnel is active via localhost.run",
    "color": 3066993,
    "fields": [
      { "name": "🔗 WebSocket IP", "value": "\`$WSS_ADDRESS\`" },
      { "name": "🛠️ Owner Console", "value": "[Click to Open Console]($CONSOLE_URL)" }
    ]
  }]
}
EOF
)
    curl -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$DISCORD_WEBHOOK"
fi

# --- 6. START MINECRAFT ---
echo "Starting Minecraft..."
tail -f server_input | bash ./run.sh &
SERVER_PID=$!

# --- 7. SHUTDOWN & AUTO-SAVE ---
sleep 13800
echo "say Server is saving and restarting..." > server_input
echo "stop" > server_input
wait $SERVER_PID

# Git Save
git add .
git commit -m "Auto-save world: $(date) [skip ci]"
git push origin main
