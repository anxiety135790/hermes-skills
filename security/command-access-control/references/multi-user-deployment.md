# Multi-User Hermes Deployment Guide

## Architecture Overview

A complete multi-user Hermes setup combines three layers:

```
WebUI User          →  Hermes Profile     →  Access Tier
826307909 (admin)   →  tg_826307909       →  ADMIN
1596476147 (other)  →  tg_1596476147      →  LIMITED
```

## Layer 1: WebUI Users

Each Telegram user gets a WebUI account at `~/.hermes/webui/users.json`.

**Key rule:** The `profile` field maps the WebUI user to a Hermes profile directory. Naming convention: `tg_<TelegramUserID>`.

**Create via API (reliable):**
```python
python3 -c "
import sys; sys.path.insert(0, '/home/milvillena99/hermes-webui')
from api.users import add_user
print(add_user('USER_ID', 'PASSWORD', profile='tg_USER_ID'))
"
```

**Delete:** `python3 /home/milvillena99/hermes-webui/scripts/manage_users.py remove USER_ID`

**Restart WebUI after changes:**
```bash
pkill -f "server\.py" && sleep 1 && cd ~/hermes-webui && python3 server.py &
```

## Layer 2: Hermes Profiles

Profiles live at `~/.hermes/profiles/<name>/`. Each is a complete Hermes home directory.

**Profile isolation:**
- ✅ Workspace (terminal cwd points to own workspace/)
- ✅ Sessions (independent history, search scope)
- ✅ Memory (independent user profile + memory state)
- ✅ Cron (each profile has its own cron jobs)
- ❌ Skills (shared via symlink → `~/.hermes/skills`)

## Layer 3: Shared Model/Provider

Profiles share **only model and provider** settings. Everything else stays per-profile.

**`~/.hermes/scripts/sync-model-provider.py`** syncs these keys from source → all other profiles:
- `model` (model.default, model.provider, model.api_key)
- `custom_providers`
- `fallback_providers`, `providers`, `credential_pool_strategies`

**Usage:**
```bash
# Sync from default source (tg_826307909):
python3 ~/.hermes/scripts/sync-model-provider.py

# Sync from specific source:
python3 ~/.hermes/scripts/sync-model-provider.py tg_1596476147
```

**When to sync:** Run after changing model, provider, or API keys.

## Layer 4: Gateway Restart Monitoring

When gateway restarts, auto-verify all services:

**Watchdog:** `~/.hermes/scripts/gateway-watchdog.sh`
- Compares gateway PID against `~/.hermes/.gateway_last_pid`
- If PID changed, runs full service status check

**Status check:** `~/.hermes/scripts/check-hermes-status.sh`
- Checks: Gateway → WebUI → Caddy → Cron → Profiles → Disk

**Cron job (every 2m, no_agent):**
```
name: Gateway 重启监控
schedule: every 2m
deliver: origin
no_agent: true
script: gateway-watchdog.sh
```

## Maintenance: Backup Must Include Profiles

When profiles exist (`~/.hermes/profiles/<name>/`), the default backup script at `backup_hermes.sh` will **silently miss profile data** if it copies skills first (skills are large → backup times out before reaching profiles). Fix:

**Restore backup script to copy profiles BEFORE skills:**

```bash
# GOOD: profiles first, skills last
for item in config.yaml SOUL.md cron memories sessions plans workspace; do
    [ -e "$profile/$item" ] && cp -a "$profile/$item" "$dest/" 2>/dev/null || true
done
# ... then skills at the end
```

**What each profile contains (backup-worthy):**
- `config.yaml` — per-profile settings
- `SOUL.md` — per-profile system prompt
- `cron/` — per-profile scheduled jobs
- `memories/` — per-profile memory state
- `sessions/` — per-profile session history
- `plans/` — per-profile saved plans
- `workspace/` — per-profile terminal workspace

**Do NOT backup:** `skills/` (symlinked to root shared `~/.hermes/skills`), `skins/` (global), `state.db*` (recreatable).

**Verify backup completeness after any script change:**
```bash
ls ~/.hermes/bk/backup_latest/profiles/   # should list all profiles
du -sh ~/.hermes/bk/backup_latest/         # should be > root-only backups
```

## Full Setup Sequence (New User)

```bash
# 1. Create WebUI user
python3 -c "
import sys; sys.path.insert(0, '/home/milvillena99/hermes-webui')
from api.users import add_user
add_user('USER_ID', 'PASSWORD', profile='tg_USER_ID')
"

# 2. Create profile dirs
mkdir -p ~/.hermes/profiles/tg_USER_ID/{workspace,sessions,memories,cron,logs,plans,skins}
ln -s ~/.hermes/skills ~/.hermes/profiles/tg_USER_ID/skills

# 3. Copy base config from reference profile
cp ~/.hermes/profiles/tg_826307909/config.yaml ~/.hermes/profiles/tg_USER_ID/config.yaml

# 4. Fix workspace cwd in config.yaml
sed -i 's|tg_826307909/workspace|tg_USER_ID/workspace|' ~/.hermes/profiles/tg_USER_ID/config.yaml

# 5. Sync model/provider
python3 ~/.hermes/scripts/sync-model-provider.py

# 6. Add to access control (~/.hermes/hooks/check_access.py)
#    LIMITED_USER_IDS.add("USER_ID")
#    USER_WORKSPACES["USER_ID"] = "/path/to/jail"
#    USER_SESSION_DIRS["USER_ID"] = "/path/to/sessions"

# 7. Restart WebUI
pkill -f "server\.py" && sleep 1 && cd ~/hermes-webui && python3 server.py &
```
