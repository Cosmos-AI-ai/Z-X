#!/bin/bash

# --- 1. Fix Server Port ---
# This ensures your server.properties matches your tunnel port
sed -i 's/server-port=.*/server-port=2252/' server.properties

# --- 2. Start e4mc Tunnel ---
curl -L https://github.com/e4mc/e4mc-cli/releases/latest/download/e4mc-cli-linux-amd64 -o e4mc
chmod +x e4mc

# Start tunnel using the identity file to keep the URL fixed
./e4mc tcp 2252 --config ./e4mc_identity.json > tunnel.log 2>&1 &
sleep 15

# Grab the public address from the log
ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.e4mc\.link" tunnel.log | head -n 1)

# --- 3. Discord Notification ---
curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🏰 **Server is ONLINE!**\n🔗 **IP:** \`$ADDRESS\`\n⏰ **Duration:** 3 PM - 7 PM IST\"}" $DISCORD_WEBHOOK

# --- 4. Start Minecraft ---
java -Xmx4G -jar server.jar nogui &
SERVER_PID=$!

# --- 5. Shutdown Logic ---
# Wait 3 hours 50 minutes
sleep 13800

# 10 Minute Warning
echo "say ⚠️ Server shutting down in 10 minutes! Saving world..." > /proc/$SERVER_PID/fd/0
curl -H "Content-Type: application/json" -X POST -d '{"content": "⚠️ **10 MINUTE WARNING:** Server closing soon!"}' $DISCORD_WEBHOOK

# 1 Minute Warning
sleep 540
echo "say ⏳ 60 SECONDS REMAINING!" > /proc/$SERVER_PID/fd/0

# 10 Second Countdown
sleep 50
for i in {10..1}; do
    echo "say Closing in $i..." > /proc/$SERVER_PID/fd/0
    sleep 1
done

# --- 6. Save and Exit ---
echo "stop" > /proc/$SERVER_PID/fd/0
wait $SERVER_PID

# Push changes (including the e4mc_identity.json for tomorrow)
git config --local user.email "action@github.com"
git config --local user.name "GitHub Action"
git add .
git commit -m "Auto-save: $(date)"
git push origin main
