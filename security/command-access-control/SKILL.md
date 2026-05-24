---
name: command-access-control
description: "Hermes security hardening: multi-tier access control via pre-command hook, workspace jail directories, per-user session isolation, secrets management (.env migration), and /model subcommand filtering."
version: 1.2.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [security, hooks, admin, permissions, telegram, multi-tenant]
---

# Command Access Control via Hooks

## What It Does

This setup restricts potentially sensitive slash commands and dangerous shell commands using a pre-command hook that validates the user's ID before execution.

**Three permission tiers:**
- **Admins** (`ADMIN_USER_IDS`): Full access — all slash commands and all arguments, all shell commands.
- **Limited Users** (`LIMITED_USER_IDS`): Can use the bot and a whitelist of safe commands. Blocked from admin commands. Workspace-restricted to a designated jail directory. Can switch models (`/model <name>`) but **cannot configure them** (`/model configure`, `--provider`, `--api-key`, etc.).
- **Everyone else**: Blocked from restricted commands by default.

**Workspace restriction:** Limited users can only operate within their assigned directory (`USER_WORKSPACES`). Any `cd`, `rm`, `mv`, `cp`, `mkdir`, `chmod`, `chown` outside that directory is blocked. Dangerous shell patterns (`rm -rf`, `dd if=`, `mkfs`, etc.) are blocked regardless of directory.

**Session isolation:** Per-user session directories (`USER_SESSION_DIRS`) can be injected via the `HERMES_SESSION_DIR` env var. Note: Hermes sessions are globally stored; true per-user session isolation requires Hermes Profiles.

## How It's Implemented

1. **Hook Script**: `~/.hermes/hooks/check_access.py` (absolute path required).
2. **Config**: `config.yaml` executes this script before every command via `pre_command` hook.

### The Script: `~/.hermes/hooks/check_access.py`

Reference copy lives at `scripts/check_access.py` in this skill.

Key configuration sections:
```python
ADMIN_USER_IDS = {"826307909"}           # full access
LIMITED_USER_IDS = {"1596476147"}      # model-switch-only + workspace-restricted
ADMIN_ONLY_COMMANDS = {                  # requires admin
    "/config", "/personality", "/reasoning",
    "/voice", "/verbose", "/yolo", "/restart", "/update",
    "/sethome", "/approve", "/deny", "/tools", "/skills",
    "/reload-skills", "/reload-mcp", "/cron", "/curator",
    "/kanban", "/plugins", "/branch", "/fast", "/debug",
    "/terminal", "/bash", "/exec",
}
LIMITED_ALLOWED_COMMANDS = {             # allowed for limited users
    "/model", "/help", "/status", "/usage", "/history",
    "/save", "/copy", "/paste", "/image", "/clear",
    "/undo", "/title", "/compress", "/stop", "/queue",
    "/steer", "/goal", "/resume", "/new", "/reset", "/retry",
}
USER_WORKSPACES = {
    "1596476147": "/home/milvillena99/hermes_workspace/1596476147",
}
USER_SESSION_DIRS = {
    "1596476147": "/home/milvillena99/hermes_workspace/1596476147/sessions",
}
```

### The Config: `~/.hermes/config.yaml`

```yaml
hooks:
  pre_command:
    - command: "python3 /home/milvillena99/.hermes/hooks/check_access.py"
      on_failure: "abort" # Stops command execution if script fails
```

## Multi-User Deployment Guide

See `references/multi-user-deployment.md` for the full workflow: combining WebUI users + Hermes Profiles + shared model/provider sync + access control tiers + gateway restart monitoring.

The profile sync script lives at `~/.hermes/scripts/sync-model-provider.py` — run it after changing model or provider settings to propagate changes to all profiles. The gateway restart watchdog (`~/.hermes/scripts/gateway-watchdog.sh`) auto-notifies you when services need a post-restart check.

## Secrets Management: API Key → .env Migration

For comprehensive details including example code and backup automation, see [`references/secrets-env-migration.md`](references/secrets-env-migration.md).

### Quick Summary

Hermes `config.yaml` stores API keys inline by default. Moving them to `~/.hermes/.env` improves security and makes `config.yaml` safe to share.

**Step 1:** Add variables to `~/.hermes/.env` (no quotes, no `export`):
```env
CENTOS_HK_V1_API_KEY=sk-xxx
DEEPSEEK_API_KEY=sk-21e7b...
```

**Step 2:** In `config.yaml`, replace inline values with `${VAR_NAME}` references:
```yaml
# Before:
api_key: sk-xxx

# After:
api_key: ${CENTOS_HK_V1_API_KEY}
```

**Step 3:** Verify and restart:
```bash
hermes doctor
hermes gateway restart
```

### Naming Convention for Multi-Provider Keys

Each provider's key gets an independent name for easy rotation:
```env
CENTOS_HK_V1_API_KEY=sk-xxx           # Chinese_model_x0.4
CENTOS_HK_ANTHROPIC_API_KEY=sk-yyy     # deepseek_x0.4 (Anthropic mode)
DEEPSEEK_API_KEY=sk-zzz               # DeepSeek native
```

### Backup Before Migrating

```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.backup-$(date +%Y%m%d-%H%M%S)
cp ~/.hermes/.env ~/.hermes/.env.backup-$(date +%Y%m%d-%H%M%S)
```

## Config YAML Editing Pitfalls

For details on the `hermes config set` CLI bug with nested structures and the correct patch-based workflow, see [`references/config-editing.md`](references/config-editing.md).

### Quick Summary

`hermes config set` silently produces malformed YAML for nested config structures like `custom_providers`:
```yaml
# BAD — hermes config set output
custom_providers[1]:
  - name: ...
custom_providers[2]:
  - name: ...
```

**Use the `patch` tool to edit `~/.hermes/config.yaml` directly** for any nested or list-valued settings:
```yaml
# GOOD — hand-edited
custom_providers:
  - name: Chinese_model_x0.4
    base_url: https://ai.centos.hk/v1
    api_key: ${CENTOS_HK_V1_API_KEY}
```

After editing, validate:
```bash
hermes doctor
hermes gateway restart
```

## /model Permission Detail


Limited users can **only** switch models by name:
```
/model MiniMax-M2.7          ✅ allowed
/model deepseek              ✅ allowed
/model                       ✅ allowed (shows current)
/model configure set x       ❌ blocked
/model --provider openai     ❌ blocked
/model add-provider          ❌ blocked
```

The hook checks the first argument after `/model` against a list of config subcommands (`configure`, `set`, `add`, `remove`, `delete`, `provider`, `api-key`, `base-url`, etc.) and also blocks any `--flag` arguments.

## Pitfalls

- The `command` value in `hooks.pre_command` must be an **absolute path**. `~/.hermes/hooks/...` does NOT work — Hermes does not expand shell variables in this field.
- The hook script is invoked via `python3` directly; no shebang execute bit needed.
- Changes to the hook script take effect **immediately** (no restart needed).
- Changes to the `hooks` config section require a gateway restart: `hermes gateway restart` or `/restart`.
- Available env vars to the hook: `HERMES_COMMAND_TEXT`, `HERMES_USER_ID`, `HERMES_CWD` / `PWD`, `HERMES_SESSION_ID`, `HERMES_PLATFORM`.
- Workspace restriction relies on `HERMES_CWD` — it only checks at command time. A user who `cd`s first then runs a restricted command will be blocked.
- Session directory injection (`HERMES_SESSION_DIR`) works for the running process but Hermes' `get_hermes_home() / "sessions"` is global — per-user session file isolation requires Profiles or session naming conventions embedding `user_id` in the session key.
- `allowed_chats` in `platforms.telegram.extra` only whitelists **chat IDs**, not user IDs — it cannot restrict a user to their own DM by user ID.

## How to Modify

### Add a Limited User

```python
# In check_access.py:
LIMITED_USER_IDS = {"1596476147", "ANOTHER_USER_ID"}
USER_WORKSPACES["ANOTHER_USER_ID"] = "/path/to/their/workspace"
USER_SESSION_DIRS["ANOTHER_USER_ID"] = "/path/to/their/sessions"
```

### Add an Admin

```python
ADMIN_USER_IDS = {"826307909", "NEW_ADMIN_ID"}
```

### Restrict Another Command

Add to `ADMIN_ONLY_COMMANDS`. Remove from `LIMITED_ALLOWED_COMMANDS` if present there.

### Disable

Comment out the `hooks` section in `config.yaml` and restart the gateway.
