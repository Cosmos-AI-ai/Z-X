#!/bin/bash

# --- 1. CONFIGURATION ---
# We use a unique subdomain to avoid the 'console' redirect
SUBDOMAIN="zx-$RANDOM"
DISCORD_WEBHOOK="YOUR_DISCORD_WEBHOOK_HERE"

# --- 2. SETUP ENVIRONMENT ---
# Generate SSH keys for Serveo if missing
if [ ! -f ~/.ssh/id_ed25519 ]; then
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
fi

# Create a Pipe to carry your typing into the server
rm -f server_input
mkfifo server_input

# --- 3. START LIVE CONSOLE (tmate) ---
# This gives you a browser-based terminal to control the server
sudo apt-get update && sudo apt-get install -y tmate
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait tmate-ready
CONSOLE_URL=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')

# --- 4. START SERVEO TUNNEL ---
echo "🚀 Requesting unique tunnel: $SUBDOMAIN"
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=60 \
    -R ${SUBDOMAIN}:80:localhost:25565 \
    serveo.net > tunnel.log 2>&1 &

# Extract URL (Wait up to 30 seconds)
ADDRESS=""
for i in {1..15}; do
    # Filters out the fake 'console' URL
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.serveo\.net" tunnel.log | grep -v "console" | head -n 1)
    if [ -n "$ADDRESS" ]; then break; fi
    sleep 2
done

# Fallback to entirely random name if custom one fails
if [ -z "$ADDRESS" ]; then
    echo "⚠️ Subdomain taken. Trying random..."
    pkill -f "ssh.*serveo.net"
    ssh -tt -o StrictHostKeyChecking=no -R 80:localhost:25565 serveo.net > tunnel.log 2>&1 &
    sleep 10
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.serveo\.net" tunnel.log | grep -v "console" | head -n 1)
fi

# --- 5. DISCORD NOTIFICATION (Safe JSON) ---
# Heredoc ensures no special characters break the Discord payload
PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "🏰 Server Online!",
    "color": 5763719,
    "fields": [
      { "name": "🔗 Eaglercraft IP", "value": "\`wss://$ADDRESS\`" },
      { "name": "🌍 Web Client", "value": "\`https://$ADDRESS\`" },
      { "name": "🛠️ Owner Console", "value": "[Click to Open]($CONSOLE_URL)" }
    ]
  }]
}
EOF
)

curl -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$DISCORD_WEBHOOK"

# --- 6. START MINECRAFT ---
# Pipes your browser-console typing into the server
echo "Starting Minecraft..."
tail -f server_input | bash ./run.sh &
SERVER_PID=$!

# --- 7. SHUTDOWN & AUTO-SAVE ---
# Run for ~4 hours before saving and closing
sleep 13800
echo "say Server is saving and restarting..." > server_input
echo "stop" > server_input
wait $SERVER_PID

# Git Save
git add .
git commit -m "Auto-save world: $(date) [skip ci]"
git push origin main
