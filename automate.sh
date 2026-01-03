#!/bin/bash

# --- 1. Start e4mc Tunnel ---
curl -L https://github.com/e4mc/e4mc-cli/releases/latest/download/e4mc-cli-linux-amd64 -o e4mc
chmod +x e4mc

# Start tunnel in background
./e4mc tcp 2252 --config ./e4mc_identity.json > tunnel.log 2>&1 &

# --- 2. Wait for the IP (Max 60 seconds) ---
echo "Waiting for e4mc to generate IP..."
ADDRESS=""
for i in {1..12}; do
    sleep 5
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.e4mc\.link" tunnel.log | head -n 1)
    if [ ! -z "$ADDRESS" ]; then
        echo "Found IP: $ADDRESS"
        break
    fi
    echo "Still waiting... ($((i*5))s)"
done

# --- 3. Discord Notification ---
if [ -z "$ADDRESS" ]; then
    # If it failed to get an IP, tell Discord so you aren't left guessing
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"❌ **Tunnel Error:** Could not generate an IP address. Check GitHub logs!\"}" $DISCORD_WEBHOOK
else
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🏰 **Server is ONLINE!**\n🔗 **IP:** \`$ADDRESS\`\n⏰ **Closes at:** 7 PM IST\"}" $DISCORD_WEBHOOK
fi

# --- 4. Start Minecraft ---
# Make sure server-port=2252 is in server.properties!
java -Xmx4G -jar server.jar nogui &
SERVER_PID=$!

# --- 5. Test Mode ---
# To test for just 2 minutes, change '13800' to '120'
sleep 13800

# --- 6. Shutdown Sequence ---
echo "say ⚠️ Server shutting down in 10 minutes!" > /proc/$SERVER_PID/fd/0
curl -H "Content-Type: application/json" -X POST -d '{"content": "⚠️ **10 MINUTE WARNING**"}' $DISCORD_WEBHOOK

sleep 590
echo "stop" > /proc/$SERVER_PID/fd/0
wait $SERVER_PID

# Save everything back to GitHub
git config --local user.email "action@github.com"
git config --local user.name "GitHub Action"
git add .
git commit -m "Auto-save: $(date)"
git push origin main
