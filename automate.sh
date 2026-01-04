#!/bin/bash

# --- 1. SET YOUR CUSTOM NAME ---
SUBDOMAIN="zx"

# --- 2. SETUP ENVIRONMENT ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
fi

rm -f server_input
mkfifo server_input

# --- 3. START LIVE CONSOLE (Owner Access) ---
sudo apt-get update && sudo apt-get install -y tmate
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait tmate-ready
CONSOLE_URL=$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')

# --- 4. START SERVEO TUNNEL (WITH FALLBACK) ---
echo "Attempting to get name: $SUBDOMAIN..."
ssh -tt -o StrictHostKeyChecking=no -o ServerAliveInterval=60 \
    -R ${SUBDOMAIN}:80:localhost:25565 \
    serveo.net > tunnel.log 2>&1 &

ADDRESS=""
# Try for 10 attempts (about 20-30 seconds)
for i in {1..10}; do
    # Search for a URL that is NOT 'console'
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.serveo\.net" tunnel.log | grep -v "console" | head -n 1)
    
    if [ -n "$ADDRESS" ]; then
        echo "✅ Success! Using: $ADDRESS"
        break
    fi
    echo "⏳ Attempt $i: Name taken or pending..."
    sleep 3
done

# --- FALLBACK: IF CUSTOM NAME FAILED ---
if [ -z "$ADDRESS" ]; then
    echo "⚠️ Custom name failed. Switching to ENTIRELY RANDOM name..."
    pkill -f "ssh.*serveo.net" # Kill the stuck attempt
    > tunnel.log               # Clear the log
    
    # Run WITHOUT the ${SUBDOMAIN}: part. Serveo will assign a random one.
    ssh -tt -o StrictHostKeyChecking=no -o ServerAliveInterval=60 \
        -R 80:localhost:25565 \
        serveo.net > tunnel.log 2>&1 &
        
    # Wait for the random URL
    for i in {1..10}; do
        ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.serveo\.net" tunnel.log | grep -v "console" | head -n 1)
        [ -n "$ADDRESS" ] && break
        sleep 2
    done
fi

WSS_ADDRESS="wss://$ADDRESS"

# --- 5. DISCORD NOTIFICATION ---
if [ -z "$ADDRESS" ]; then
    ERROR_MSG=$(tail -n 3 tunnel.log)
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"❌ **Critical Tunnel Error**\n\`\`\`$ERROR_MSG\`\`\`\"}" $DISCORD_WEBHOOK
else
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🏰 **Eaglercraft Online!**\n🔗 **IP:** \`$WSS_ADDRESS\`\n🛠️ **Owner Console:** $CONSOLE_URL\"}" $DISCORD_WEBHOOK
fi

# --- 6. START MINECRAFT ---
tail -f server_input | bash ./run.sh &
SERVER_PID=$!

# --- 7. SHUTDOWN & SAVE ---
sleep 13800
echo "stop" > server_input
wait $SERVER_PID

git add .
git commit -m "Auto-save world: $(date) [skip ci]"
git push origin main
