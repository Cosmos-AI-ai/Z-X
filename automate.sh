#!/bin/bash

# --- 1. SET YOUR CUSTOM NAME ---
# Change this to whatever you want! (e.g., "cool-server-2026")
SUBDOMAIN="zx-play"

# Create a Named Pipe for server input
mkfifo server_input

# --- 2. Start Serveo Tunnel ---
# We request your custom name on port 80 (to get a web/WSS link)
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 \
    -R ${SUBDOMAIN}:80:localhost:25565 \
    serveo.net > tunnel.log 2>&1 &

# --- 3. Extract the URL ---
echo "Requesting custom name: $SUBDOMAIN..."
sleep 5
ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.serveo\.net" tunnel.log | head -n 1)

# If your custom name was taken, Serveo gives you a random one.
# We extract whatever it gave us to be safe.
WSS_ADDRESS="wss://$ADDRESS"

# --- 4. Discord Notification ---
if [ -z "$ADDRESS" ]; then
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"❌ **Tunnel Error:** Could not connect to Serveo.\"}" $DISCORD_WEBHOOK
else
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🏰 **Server is ONLINE!**\n🔗 **WSS IP:** \`$WSS_ADDRESS\`\n🌍 **Web URL:** \`https://$ADDRESS\`\"}" $DISCORD_WEBHOOK
fi

# --- 5. Start Minecraft ---
tail -f server_input | java -Xmx4G -jar server.jar nogui &
SERVER_PID=$!

# --- 6. Shutdown Sequence ---
sleep 13800
echo "stop" > server_input
wait $SERVER_PID

# Git save logic...
git add .
git commit -m "Auto-save world: $(date)"
git push origin main
