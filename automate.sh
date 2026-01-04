#!/bin/bash

# --- 1. SET YOUR CUSTOM NAME ---
SUBDOMAIN="zx-play"

# --- 2. SETUP ENVIRONMENT ---
# Generate SSH keys if they don't exist (Fixes empty tunnel.log in many environments)
if [ ! -f ~/.ssh/id_ed25519 ]; then
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
fi

# Create a Named Pipe for server input
rm -f server_input
mkfifo server_input

# --- 3. START SERVEO TUNNEL ---
# -tt: Forces a terminal (prevents silent failure)
# -o UserKnownHostsFile=/dev/null: Prevents host key errors
# > tunnel.log 2>&1: Captures ALL errors and output
ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=60 \
    -R ${SUBDOMAIN}:80:localhost:25565 \
    serveo.net > tunnel.log 2>&1 &

# --- 4. EXTRACT THE URL (RETRY LOOP) ---
echo "Requesting custom name: $SUBDOMAIN..."
ADDRESS=""
for i in {1..20}; do
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.serveo\.net" tunnel.log | head -n 1)
    if [ -n "$ADDRESS" ]; then
        echo "✅ Connection established: $ADDRESS"
        break
    fi
    echo "⏳ Waiting for Serveo... ($i/20)"
    sleep 2
done

WSS_ADDRESS="wss://$ADDRESS"

# --- 5. DISCORD NOTIFICATION ---
if [ -z "$ADDRESS" ]; then
    # Log the last few lines of the error to Discord for debugging
    ERROR_MSG=$(tail -n 3 tunnel.log)
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"❌ **Tunnel Error:** Could not connect.\n\`\`\`$ERROR_MSG\`\`\`\"}" $DISCORD_WEBHOOK
else
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🏰 **Server is ONLINE!**\n🔗 **WSS IP:** \`$WSS_ADDRESS\`\n🌍 **Web URL:** \`https://$ADDRESS\`\"}" $DISCORD_WEBHOOK
fi

# --- 6. START MINECRAFT ---
# Use 'tail -f' to keep the pipe open
tail -f server_input | bash ./run.sh &
SERVER_PID=$!

# --- 7. SHUTDOWN SEQUENCE ---
# 13800 seconds = 3 hours 50 mins
sleep 13800
echo "stop" > server_input
wait $SERVER_PID

# --- 8. GIT SAVE LOGIC ---
git add .
git commit -m "Auto-save world: $(date)"
git push origin main
