#!/bin/bash
# Entry point — run this locally to start/resume the workspace

REPO="GhrayebAli/washmen-ops-workspace"
CODESPACE=$(gh codespace list --json name,state,repository -q ".[] | select(.repository == \"$REPO\" and .state == \"Available\") | .name" | head -1)

if [ -z "$CODESPACE" ]; then
  echo "No running Codespace found for $REPO. Starting..."
  CODESPACE=$(gh codespace list --json name,repository -q ".[] | select(.repository == \"$REPO\") | .name" | head -1)
  if [ -z "$CODESPACE" ]; then
    echo "No Codespace found. Create one first: gh codespace create -R $REPO -b main"
    exit 1
  fi
  gh codespace ssh -c "$CODESPACE" -- "echo started"
fi

echo "Codespace: $CODESPACE"

gh codespace ssh -c "$CODESPACE" -- 'curl -s http://localhost:4000/api/health > /dev/null 2>&1 || bash /workspaces/washmen-ops-workspace/.devcontainer/start.sh'
echo "Services starting..."

echo "Waiting for services..."
for i in $(seq 1 15); do
  PORTS=$(gh codespace ports -c "$CODESPACE" --json sourcePort -q '.[].sourcePort' 2>/dev/null)
  if echo "$PORTS" | grep -q "4000"; then break; fi
  sleep 2
done

gh codespace ports visibility -c "$CODESPACE" 4000:public 3000:public 2>/dev/null
echo "Ports set to public"

URL="https://${CODESPACE}-4000.app.github.dev"
echo ""
echo "Opening: $URL"
open "$URL" 2>/dev/null || xdg-open "$URL" 2>/dev/null || echo "Open manually: $URL"
