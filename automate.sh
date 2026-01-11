#!/bin/bash

# --- 1. SETUP ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input

# --- 2. START TUNNEL ---
ssh -R 80:localhost:25565 nokey@localhost.run \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=60 > tunnel.log 2>&1 &

# --- 3. WAIT FOR URL & DISCORD ---
ADDRESS=""
for i in {1..20}; do
    ADDRESS=$(grep -oE "[a-zA-Z0-9.-]+\.lhr\.(life|pro)" tunnel.log | head -n 1)
    if [ -n "$ADDRESS" ]; then break; fi
    sleep 3
done

if [ -n "$ADDRESS" ]; then
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🛠️ **Eaglercraft Online** (3PM-7PM IST)\\n🔗 **IP:** \`wss://$ADDRESS\`\"}" "$DISCORD_WEBHOOK"
fi

# --- 4. 4-HOUR TIMER WITH 30s COUNTDOWN ---
(
  sleep 1770 # Wait until 6:59:30 PM IST   14370
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds! Saving world..." > server_input
    sleep 1
  done
  echo "stop" > server_input
) &

# --- 5. START SERVER ---
tail -f server_input | bash ./run.sh

# --- 6. PUSH BACK TO GITHUB ---
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .
git commit -m "Automated Save: $(date)" || echo "No changes to save"
git push origin main
