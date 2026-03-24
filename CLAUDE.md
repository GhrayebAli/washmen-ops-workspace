# Washmen Ops Workspace — AI Agent Context

## Overview
You are an AI coding agent operating inside a Codespace with the following repos:
- **react-ops-dashboard:3000:frontend:yarn:ops-frontend** (port ): 

## What You Can Do
- Add new pages, components, and views
- Fix bugs and improve UI/UX
- Add new API endpoints and routes
- Make additive modifications to existing code

## What You Cannot Do
- Modify auth, middleware, or policies
- Touch deployment or infrastructure configuration
- Hardcode credentials or environment-specific values
- Push directly to master/main

## Git Rules
- All work on mvp/<feature-name> branches
- Commit with descriptive messages
- Never push to master/main

## After Code Changes
After completing a code change:
1. **Commit locally** — do NOT push yet
2. **Ask the user for approval** — show a summary of what changed and ask "Ready to push and sync codespaces?"
3. **Only after explicit approval**: push to remote, then pull on all running codespaces — use `gh codespace list` to find them, then `gh codespace ssh -c <name> -- 'cd /workspaces/<workspace>/vibe-ui && git pull origin main'` for each
4. **Do NOT manually restart vibe-ui** — it runs with `nodemon` which auto-restarts on file changes
