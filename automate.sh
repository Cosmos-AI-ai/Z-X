#!/bin/bash

# --- 1. SET YOUR CUSTOM NAME ---
# Added a random number so you don't get the 'console.serveo.net' error
SUBDOMAIN="zx$RANDOM"

# --- 2. SETUP ENVIRONMENT ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
fi

rm -f server_input
mkfifo server_input

# --- 3. START LIVE CONSOLE (For the Owner) ---
# This gives you a link to type into the server live!
sudo apt-get update && sudo apt-get install -y tmate
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait tmate-ready
CONSOLE_URL=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')

# --- 4. START SERVEO TUNNEL ---
# We use port 80 so Serveo provides the SSL for wss://
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=60 \
    -R ${SUBDOMAIN}:80:localhost:25565 \
    serveo.net > tunnel.log 2>&1 &

# --- 5. EXTRACT THE REAL URL ---
echo "Requesting unique name: $SUBDOMAIN..."
ADDRESS=""
for i in {1..30}; do
    # This specifically ignores 'console.serveo.net'
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.serveo\.net" tunnel.log | grep -v "console" | head -n 1)
    if [ -n "$ADDRESS" ]; then
        echo "✅ Connection established: $ADDRESS"
        break
    fi
    echo "⏳ Waiting for valid tunnel... ($i/30)"
    sleep 2
done

WSS_ADDRESS="wss://$ADDRESS"

# --- 6. DISCORD NOTIFICATION ---
if [ -z "$ADDRESS" ]; then
    ERROR_MSG=$(tail -n 5 tunnel.log)
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"❌ **Tunnel Error:**\n\`\`\`$ERROR_MSG\`\`\`\"}" $DISCORD_WEBHOOK
else
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🏰 **Eaglercraft ONLINE!**\n🔗 **IP:** \`$WSS_ADDRESS\`\n🛠️ **Owner Console:** $CONSOLE_URL\"}" $DISCORD_WEBHOOK
fi

# --- 7. START MINECRAFT ---
# Use 'tail -f' to keep the pipe open for your commands
tail -f server_input | bash ./run.sh &
SERVER_PID=$!

# --- 8. SHUTDOWN SEQUENCE ---
sleep 13800
echo "stop" > server_input
wait $SERVER_PID

# --- 9. GIT SAVE LOGIC ---
git add .
git commit -m "Auto-save world: $(date) [skip ci]"
git push origin main
