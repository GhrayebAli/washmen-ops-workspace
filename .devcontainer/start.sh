#!/bin/bash
# Generic service startup — reads everything from workspace.json
# This script is identical across all workspaces.

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspaces/$(basename "$(pwd)")}"
cd "$WORKSPACE_DIR"

echo "=== Starting services ==="

# ── Wait for setup to finish on first boot ──
WAIT=0
while [ ! -f "$WORKSPACE_DIR/.setup-done" ] && [ $WAIT -lt 300 ]; do
  echo "Waiting for setup to complete... (${WAIT}s)"
  sleep 5
  WAIT=$((WAIT + 5))
done

if [ ! -f "workspace.json" ]; then
  echo "ERROR: workspace.json not found"
  exit 1
fi

REPO_COUNT=$(jq '.repos | length' workspace.json)

# ── Ensure deps exist ──
for i in $(seq 0 $((REPO_COUNT - 1))); do
  NAME=$(jq -r ".repos[$i].name" workspace.json)
  PKG_MGR=$(jq -r ".repos[$i].packageManager // \"npm\"" workspace.json)
  NODE_OPTS=$(jq -r ".repos[$i].nodeOptions // empty" workspace.json)

  if [ -d "$WORKSPACE_DIR/$NAME" ] && [ ! -d "$WORKSPACE_DIR/$NAME/node_modules" ]; then
    echo "$NAME deps missing — installing..."
    (
      cd "$WORKSPACE_DIR/$NAME"
      if [ "$PKG_MGR" = "yarn" ]; then
        sudo corepack enable 2>/dev/null || true
        [ -n "$NODE_OPTS" ] && export NODE_OPTIONS="$NODE_OPTS"
        yarn install
      else
        npm install
      fi
    )
  fi
done

if [ ! -d "$WORKSPACE_DIR/vibe-ui/node_modules" ]; then
  echo "vibe-ui deps missing — installing..."
  (cd "$WORKSPACE_DIR/vibe-ui" && npm install)
fi

# ── Restore active branch ──
if [ -f "$WORKSPACE_DIR/.active-branch" ]; then
  BRANCH=$(cat "$WORKSPACE_DIR/.active-branch")
  echo "Restoring branch: $BRANCH"
  for i in $(seq 0 $((REPO_COUNT - 1))); do
    NAME=$(jq -r ".repos[$i].name" workspace.json)
    git -C "$WORKSPACE_DIR/$NAME" checkout "$BRANCH" 2>/dev/null || true
  done
fi

# ── Clear old logs ──
for f in /tmp/*.log; do > "$f" 2>/dev/null; done

# ── Kill leftover processes on configured ports ──
for i in $(seq 0 $((REPO_COUNT - 1))); do
  PORT=$(jq -r ".repos[$i].port // empty" workspace.json)
  [ -n "$PORT" ] && kill $(lsof -ti:$PORT -sTCP:LISTEN) 2>/dev/null || true
done
kill $(lsof -ti:4000 -sTCP:LISTEN) 2>/dev/null || true
sleep 1

# ── Enable corepack for yarn-based repos ──
sudo corepack enable 2>/dev/null || true

# ── Start services from workspace.json ──
for i in $(seq 0 $((REPO_COUNT - 1))); do
  NAME=$(jq -r ".repos[$i].name" workspace.json)
  PORT=$(jq -r ".repos[$i].port // empty" workspace.json)
  DEV=$(jq -r ".repos[$i].dev // empty" workspace.json)
  NODE_OPTS=$(jq -r ".repos[$i].nodeOptions // empty" workspace.json)

  if [ -z "$DEV" ] || [ ! -d "$WORKSPACE_DIR/$NAME/node_modules" ]; then
    echo "WARN: $NAME — skipping (no dev command or missing deps)"
    continue
  fi

  ENV_PREFIX=""
  [ -n "$NODE_OPTS" ] && ENV_PREFIX="export NODE_OPTIONS=$NODE_OPTS && "

  LOG="/tmp/${NAME}.log"
  (cd "$WORKSPACE_DIR/$NAME" && eval "${ENV_PREFIX}${DEV}" >> "$LOG" 2>&1) &
  echo "$NAME starting on :$PORT"
done

# ── Start vibe-ui (always port 4000) ──
if [ -d "$WORKSPACE_DIR/vibe-ui/node_modules" ]; then
  (cd "$WORKSPACE_DIR/vibe-ui" && ANTHROPIC_API_KEY=$(cat .env 2>/dev/null | grep ANTHROPIC | cut -d= -f2) node server-washmen.js >> /tmp/vibe.log 2>&1) &
  echo "vibe-ui starting on :4000"
fi

echo "=== All services starting in background ==="

# Keep the script alive so background processes aren't reaped
# when the devcontainer lifecycle process exits
wait
