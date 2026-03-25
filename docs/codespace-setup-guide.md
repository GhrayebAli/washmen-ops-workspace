# Washmen Codespace Setup Guide

A structured guide for setting up a new Codespace workspace with VPN connectivity, backend services, and frontend—based on lessons learned from the washmen-ops-workspace setup.

---

## Prerequisites

### 1. GitHub Access
- GitHub account with Codespaces enabled
- `gh` CLI authenticated (`gh auth login`)
- Repository created under your GitHub org/user

### 2. VPN Configuration
- OpenVPN-compatible `.ovpn` config file from your DevOps team
- The `.ovpn` file must contain only PEM-encoded blocks (no human-readable cert dumps)
- Private key extracted separately for storage as a Codespace secret

### 3. Codespace Secrets (repo-level)
Set these **before** creating the Codespace. Go to: Repo Settings > Secrets and variables > Codespaces.

| Secret | Purpose | How to get |
|---|---|---|
| `WASHMEN_GITHUB_TOKEN` | Git auth for private repos + npm packages | GitHub PAT with `repo` scope |
| `ANTHROPIC_API_KEY` | Claude/vibe-ui AI features | Anthropic dashboard |
| `VPN_PRIVATE_KEY` | OpenVPN private key (full PEM with headers) | DevOps team |
| `AWS_ACCESS_KEY_ID` | DynamoDB, S3, SNS access | `~/.aws/credentials` or IAM console |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | Same as above |
| `VIEWS_PGPASSWORD` | PostgreSQL password | DevOps team |
| `REDSHIFT_WAREHOUSE_DB_PASSWORD` | Redshift password | DevOps team |
| `INTERNAL_USER_AUTH_SALT` | Auth password hashing | DevOps team |
| `INTERCOM_ACCESS_TOKEN` | Intercom API | Intercom dashboard |
| `GOOGLE_PLACES_API_KEY` | Google Places API | Google Cloud Console |
| `GOOGLE_MAPS_KEY` | Google Maps (frontend) | Google Cloud Console |
| `ALGOLIA_APP_ID` | Algolia search (frontend) | Algolia dashboard |
| `ALGOLIA_API_KEY` | Algolia search key (frontend) | Algolia dashboard |
| `SENTRY_DSN` | Error reporting | Sentry dashboard |
| `E2E_CLIENT_ID` | Cognito machine auth client ID | AWS Cognito console |
| `E2E_CLIENT_SECRET` | Cognito machine auth client secret | AWS Cognito console |

**Important:** All secrets must be set before the first `gh codespace create`. The `postCreateCommand` runs once on creation and uses these secrets to generate `.env` files. Missing secrets = empty values in `.env` files.

### 4. Infrastructure Requirements
- Backend services accessible via VPN (load balancer, databases, Redis, DynamoDB)
- Cognito user pool configured with machine-to-machine auth
- At least one test user in DynamoDB (`ops_users` table)

---

## Architecture Overview

```
Browser (your machine)
  │
  ├── :3000 (ops-frontend) ──── public, Codespace forwarded URL
  ├── :4000 (vibe-ui) ────────── public, Codespace forwarded URL
  ├── :1339 (internal-public-api) ── public, for browser API calls
  └── :2339 (srv-internal-user-backend) ── private, internal only
          │
          └── VPN tunnel ──── internal LB, Redis, DynamoDB, RDS, etc.
```

### Service Communication Flow
```
Browser → :3000 (frontend) → REACT_APP_INTERNAL_API_OPS → :1339 (public-api)
  :1339 → SRV_INTERNAL_BACKEND_URL → :2339 (user-backend, local)
  :1339 → SRV_*_BACKEND_URL → internal LB (other microservices via VPN)
  :2339 → DynamoDB, PostgreSQL, Redis (via VPN)
```

### Auth Flow
```
1. Browser → POST :3000/__dev-machine-auth (webpack dev server proxy)
2. Dev server → POST dev-ops-auth.washmen.com/oauth2/token (Cognito)
3. Dev server → POST :1339/auth/testing-callback (local public-api)
4. Public-api → :2339/users/list-by-email (local user-backend → DynamoDB)
5. Public-api → creates AuthToken in memory store
6. Browser gets authToken, uses it for all subsequent API calls to :1339
```

---

## Common Pitfalls & Solutions

### 1. CWD Pollution in Shell Scripts
**Problem:** `cd` into a repo dir for `npm install` leaves the shell in the wrong directory for the next iteration.
**Solution:** Always use subshells: `(cd "$DIR" && npm install)` — the parentheses isolate the `cd`.

### 2. Secrets Not Available in SSH Sessions
**Problem:** `gh codespace ssh` does not inject Codespace secrets into the environment.
**Solution:** Secrets are only available during lifecycle commands (`postCreateCommand`, `postStartCommand`). Generate all config files during `postCreateCommand`. Never rely on SSH to re-run setup.

### 3. `envsubst` Expands Too Much
**Problem:** `envsubst` with no args replaces ALL `$VAR` patterns, including `$npm_package_version`.
**Solution:** Pass a specific variable list: `envsubst "$VAR1 $VAR2"`. Only expand known Codespace secrets.

### 4. Background Processes Killed on Lifecycle Exit
**Problem:** `nohup cmd &` in `postStartCommand` — the background process gets reaped when the lifecycle shell exits.
**Solution:** Run the main script in foreground and use `wait` at the end to keep it alive:
```json
"postStartCommand": "bash start-openvpn.sh; bash start.sh"
```
Where `start.sh` launches services with `&` and ends with `wait`.

### 5. Trailing Slashes in Service URLs
**Problem:** `SRV_INTERNAL_BACKEND_URL=http://localhost:2339/` + `/users/list` = `//users/list` → 404.
**Solution:** Never include trailing slashes in service URLs. The hooks append paths with leading slashes.

### 6. Browser Can't Reach localhost Ports
**Problem:** Frontend runs in the browser on your machine. `REACT_APP_INTERNAL_API_OPS=http://localhost:1339` doesn't work — nothing runs on your machine's port 1339.
**Solution:** Use the Codespace forwarded URL: `https://<codespace-name>-1339.app.github.dev/`. Auto-patch in `setup.sh`:
```bash
if [ "$CODESPACES" = "true" ] && [ -n "$CODESPACE_NAME" ]; then
  API_URL="https://${CODESPACE_NAME}-1339.app.github.dev"
  sed -i "s|REACT_APP_INTERNAL_API_OPS=.*|REACT_APP_INTERNAL_API_OPS=${API_URL}/|" .env.development
fi
```
Port must be set to **public** visibility.

### 7. E2E Auth Must Hit Local API
**Problem:** `REACT_APP_E2E_INTERNAL_API_OPS` pointing to external dev API creates AuthTokens there, but the local public-api doesn't recognize them.
**Solution:** Point to `http://localhost:1339` — the `setupProxy.js` call is server-side (runs inside the Codespace), so localhost is reachable.

### 8. `ENABLE_SENTRY` Crash
**Problem:** `process.env.ENABLE_SENTRY.toUpperCase()` crashes when the env var is unset.
**Solution:** Set `ENABLE_SENTRY=false` in both backend `.env` files.

### 9. Corepack/Yarn Hangs
**Problem:** First `yarn install` hangs because corepack hasn't downloaded the Yarn binary.
**Solution:** Pre-activate in `postCreateCommand`:
```
sudo corepack enable && corepack prepare yarn@3.2.4 --activate
```

### 10. VPN Config Template
**Problem:** `.ovpn` file with human-readable cert dump before the PEM block causes OpenVPN parse failure.
**Solution:** Only include PEM-encoded blocks (`-----BEGIN/END CERTIFICATE-----`) in the template. Remove `openssl x509 -text` output.

---

## Step-by-Step: Adding a New Backend Service

1. **Explore the repo** — identify:
   - Framework (Sails.js, Express, etc.)
   - Port (check `config/env/development.js`)
   - Package manager (`npm` or `yarn`)
   - Default branch (`main` or `master`)

2. **Identify ALL env vars** — check:
   - `config/` directory for `process.env.*` references
   - `node_modules/@washmen/sails-hook-*` for `process.env.SRV_*` service URLs
   - `app.js` and `sentry-instrument.js` for startup requirements
   - `api/helpers/` for database/Redis connection configs

3. **Classify vars** as secrets vs config:
   - Secrets: passwords, API keys, access tokens, salts → Codespace secrets
   - Config: URLs, ports, region names, feature flags → `workspace.json` envFiles

4. **Test startup blockers** — identify what crashes the service:
   - Missing database credentials → service won't lift
   - Missing Redis host → ORM init fails
   - Missing `ENABLE_SENTRY` → error handler crashes (masking real errors)
   - Missing AWS credentials → DynamoDB/S3/SNS calls fail

5. **Update workspace.json:**
   - Add repo to `repos` array with port, dev command, branch
   - Add `.env` to `envFiles` with all vars (use `$SECRET_NAME` for secrets)
   - No trailing slashes on service URLs

6. **Update devcontainer.json:**
   - Add port to `forwardPorts`
   - Add port to `portsAttributes`
   - Add any new secrets to `secrets`

7. **Update setup.sh:**
   - Add new secret names to the `envsubst` variable list

8. **Update .gitignore:**
   - Add the new repo directory

9. **Test** — create a fresh Codespace and verify:
   - Deps install without hanging
   - `.env` files have expanded secrets
   - Service starts and listens on its port
   - Health checks pass
   - Auth flow works end-to-end

---

## Quick Reference: Lifecycle Commands

| Phase | Runs when | Has secrets? | Purpose |
|---|---|---|---|
| `postCreateCommand` | Create, full rebuild | Yes | Install packages, generate .env files, setup VPN config |
| `postStartCommand` | Every start/restart | No (but persisted files exist) | Start VPN, start services |

**Key insight:** Generate all config files in `postCreateCommand` (secrets available). Start services in `postStartCommand` (files already on disk from create).

---

## Quick Reference: Debugging

```bash
# Check VPN
cat .devcontainer/openvpn-tmp/openvpn.log

# Check service logs
tail -f /tmp/internal-public-api.log
tail -f /tmp/srv-internal-user-backend.log
tail -f /tmp/ops-frontend.log
tail -f /tmp/vibe.log

# Check ports
lsof -i :1339 -sTCP:LISTEN
lsof -i :2339 -sTCP:LISTEN
lsof -i :3000 -sTCP:LISTEN
lsof -i :4000 -sTCP:LISTEN

# Test auth flow
curl -s -X POST http://localhost:3000/__dev-machine-auth | jq .

# Test API with token
TOKEN=$(curl -s -X POST http://localhost:3000/__dev-machine-auth | jq -r .authToken)
curl -s "http://localhost:1339/customers?page=1&size=2" -H "Authorization: Bearer $TOKEN" | jq .
```
