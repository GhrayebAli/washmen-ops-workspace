#!/bin/bash
# Generic workspace setup — reads everything from workspace.json
# This script is identical across all workspaces.

set -e

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspaces/$(basename "$(pwd)")}"
cd "$WORKSPACE_DIR"

echo "=== Workspace Setup ==="
START_TIME=$(date +%s)

# ── Parse workspace.json ──
if [ ! -f "workspace.json" ]; then
  echo "ERROR: workspace.json not found in $WORKSPACE_DIR"
  exit 1
fi

WORKSPACE_NAME=$(jq -r '.name' workspace.json)
echo "Workspace: $WORKSPACE_NAME"

# ── Configure git auth ──
git config --global commit.gpgsign false
GIT_TOKEN="${WASHMEN_GITHUB_TOKEN:-$GITHUB_PAT}"
if [ -n "$GIT_TOKEN" ]; then
  # Configure auth for each git org in workspace.json
  for org in $(jq -r '.gitOrgs[]? // empty' workspace.json); do
    git config --global url."https://x-access-token:${GIT_TOKEN}@github.com/${org}/".insteadOf "https://github.com/${org}/"
    echo "Git auth configured for $org"
  done

  # npm auth for @washmen/ packages (if Washmen org is listed)
  if jq -e '.gitOrgs[]? | select(. == "Washmen")' workspace.json > /dev/null 2>&1; then
    echo "@washmen:registry=https://npm.pkg.github.com/" > ~/.npmrc
    echo "//npm.pkg.github.com/:_authToken=${GIT_TOKEN}" >> ~/.npmrc
    echo "npm auth configured for @washmen/ packages"
  fi
fi

# ── Clone repos ──
echo "Cloning repos..."

REPO_COUNT=$(jq '.repos | length' workspace.json)
for i in $(seq 0 $((REPO_COUNT - 1))); do
  NAME=$(jq -r ".repos[$i].name" workspace.json)
  URL=$(jq -r ".repos[$i].url // empty" workspace.json)
  CHECK_DIR=$(jq -r ".repos[$i].checkDir // \"package.json\"" workspace.json)

  if [ -z "$URL" ]; then
    echo "Skipping $NAME — no URL"
    continue
  fi

  # Check if already cloned
  if [ -e "$WORKSPACE_DIR/$NAME/$CHECK_DIR" ]; then
    echo "$NAME already cloned — skipping"
    continue
  fi

  # Private repos need token
  if echo "$URL" | grep -q "github.com" && [ -z "$GIT_TOKEN" ]; then
    # Check if repo is under a private org
    ORG=$(echo "$URL" | sed 's|.*/\([^/]*\)/.*|\1|')
    IS_PRIVATE=$(jq -r ".repos[$i].isPrivate // false" workspace.json)
    if [ "$IS_PRIVATE" = "true" ]; then
      echo "Skipping $NAME — no git token for private repo"
      continue
    fi
  fi

  rm -rf "$NAME"
  git clone "$URL" "$NAME" --depth 1
  echo "Cloned $NAME ($(( $(date +%s) - START_TIME ))s)"
done

# Clone vibe-ui (always from GhrayebAli, public)
[ -f "vibe-ui/server-washmen.js" ] || (rm -rf vibe-ui && git clone https://github.com/GhrayebAli/vibe-ui.git vibe-ui && echo "Cloned vibe-ui")

# ── Install dependencies (skip if already installed) ──

for i in $(seq 0 $((REPO_COUNT - 1))); do
  NAME=$(jq -r ".repos[$i].name" workspace.json)
  PKG_MGR=$(jq -r ".repos[$i].packageManager // \"npm\"" workspace.json)
  NODE_OPTS=$(jq -r ".repos[$i].nodeOptions // empty" workspace.json)

  if [ ! -d "$WORKSPACE_DIR/$NAME" ]; then continue; fi
  if [ -d "$WORKSPACE_DIR/$NAME/node_modules" ]; then
    echo "$NAME deps already installed — skipping"
    continue
  fi

  echo "Installing $NAME dependencies ($PKG_MGR)..."
  cd "$WORKSPACE_DIR/$NAME"

  if [ "$PKG_MGR" = "yarn" ]; then
    sudo corepack enable 2>/dev/null || true
    [ -n "$NODE_OPTS" ] && export NODE_OPTIONS="$NODE_OPTS"
    yarn install
  else
    npm install
  fi

  echo "$NAME installed ($(( $(date +%s) - START_TIME ))s)"
done

# vibe-ui deps
if [ ! -d "$WORKSPACE_DIR/vibe-ui/node_modules" ]; then
  echo "Installing vibe-ui dependencies..."
  cd "$WORKSPACE_DIR/vibe-ui" && npm install
  echo "vibe-ui installed ($(( $(date +%s) - START_TIME ))s)"
fi

# ── Create .env files from workspace.json ──

if [ -n "$ANTHROPIC_API_KEY" ]; then
  echo "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" > "$WORKSPACE_DIR/vibe-ui/.env"
  echo "API key written to vibe-ui/.env"
fi

# Write env files defined in workspace.json
for NAME in $(jq -r '.envFiles // {} | keys[]' workspace.json 2>/dev/null); do
  if [ ! -d "$WORKSPACE_DIR/$NAME" ]; then continue; fi
  for ENV_FILE in $(jq -r ".envFiles[\"$NAME\"] | keys[]" workspace.json 2>/dev/null); do
    CONTENT=$(jq -r ".envFiles[\"$NAME\"][\"$ENV_FILE\"]" workspace.json)
    echo -e "$CONTENT" > "$WORKSPACE_DIR/$NAME/$ENV_FILE"
    echo "Created $NAME/$ENV_FILE"
  done
done

# ── Signal setup complete ──
touch "$WORKSPACE_DIR/.setup-done"

echo "=== Setup complete ($(( $(date +%s) - START_TIME ))s) ==="
