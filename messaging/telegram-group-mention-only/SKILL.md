---
name: telegram-group-mention-only
description: "Configure Hermes Telegram bot to only respond in groups when explicitly @mentioned — reduces spam and cost."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [telegram, group, mention, configuration]
    platforms: [telegram]
---

# Telegram Group: Only Reply When @Mentioned

## What It Does

In Telegram groups, the bot **stays silent** unless:
- Someone @mentions the bot directly
- Someone replies to a bot message
- The chat is in `free_response_chats` (whitelisted)

In **DMs**, the bot always responds normally — mention rules don't apply.

## Enable

```bash
hermes config set telegram.require_mention true
# Or in config.yaml:
# telegram:
#   require_mention: true
```

Then restart the gateway:
```
/restart
```
Or from CLI: `hermes gateway restart`

## Disable (back to always respond in groups)

```bash
hermes config set telegram.require_mention false
hermes gateway restart
```

## Fine-Grained Options

### Whitelist specific group chats (skip mention check)

Groups in `free_response_chats` get responses without needing @mention:

```yaml
telegram:
  require_mention: true
  free_response_chats: "-1001234567890,-1009876543210"
```

Can also set via env var:
```bash
export TELEGRAM_FREE_RESPONSE_CHATS="-1001234567890,-1009876543210"
```

### Custom mention patterns (regex wake words)

Instead of requiring @mention, match custom text patterns:

```yaml
telegram:
  mention_patterns:
    - "^hermes"
    - "hey bot"
    - "!respond"
```

Or via env var (JSON array or comma/newline separated):
```bash
export TELEGRAM_MENTION_PATTERNS='["^hermes","hey bot"]'
```

### Ignore specific forum topics/threads

```yaml
telegram:
  ignored_threads: [12345, 67890]
```

```bash
export TELEGRAM_IGNORED_THREADS="12345,67890"
```

## How the Gating Logic Works

`_should_process_message()` in `gateway/platforms/telegram.py`:

```
1. DM chat?                    → always process
2. Thread in ignored_threads?  → skip
3. Chat in free_response_chats? → process
4. require_mention = false?     → process
5. Reply to bot message?        → process
6. @mentions bot username?      → process
7. Matches mention_patterns?    → process
                                   otherwise → skip
```

## Verify It's Working

1. Send a message in a group **without** @mentioning the bot → should get no response
2. Send a message **with** @mention → bot should respond
3. DM the bot directly → should always respond

## Telegram Command Menu

When connected, Hermes registers up to 100 slash commands to the Telegram bot's `/commands` menu (Bot API menu limitations). Commands beyond 100 are hidden — use `/commands` in Telegram to see the full list.

**Notable gaps that are by design:**
- `/start` — not registered; Hermes does not expose Telegram's `/start` command. Sending `/start` to the bot returns "unknown command." Use plain messages or `/help` instead.
- Standard Telegram bot commands like `/help`, `/settings` are not auto-registered; Hermes' own `/help` slash command covers all available commands.

## DM Topics / Forum Topics in Private Chats

Hermes supports **DM Topics** (Bot API 9.4 — Private Chat Topics): named threads inside a DM conversation, similar to forum topics. This is different from group forum topics.

### How DM Topics Work

Configured in `config.yaml` under `platforms.telegram.extra.dm_topics`:

```yaml
telegram:
  extra:
    dm_topics:
      - chat_id: 123456789
        topics:
          - name: "会话1"
            thread_id: 98771   # optional — if omitted, Hermes creates it via API
          - name: "Accessibility Auditor"
            icon_color: 9367192
            skill: "accessibility-auditor"
```

If `thread_id` is not provided, Hermes calls `createForumTopic` via the Telegram Bot API. If the bot lacks `Bot_forum_create_forbidden` permission (or `/start` was initiated from the DM itself), creation fails with `Bot_forum_create_forbidden`.

### Error: "Bot_forum_create_forbidden"

```
Failed to create DM topic 'Hermes' in chat 826307909: Bot_forum_create_forbidden
```

**Cause**: The bot tried to create a forum topic but doesn't have the "Can create forum topics" admin permission. This commonly occurs when:
- The bot tries to auto-create a DM topic on first DM contact
- The bot is in a group but lacks topic-creation rights

**Fix**: Add `dm_topics: []` (empty) to disable auto-creation:

```yaml
telegram:
  extra:
    dm_topics: []
```

This prevents Hermes from attempting to create topics via the API. Without this config, Hermes may still cache a `thread_id` from a previous session and try to use it, causing "Thread N not found" warnings.

### Error: "Thread N not found, retrying without message_thread_id"

When Hermes tries to send a message with `message_thread_id` set to a topic that no longer exists. Telegram returns a `BadRequest` → Hermes retries without the thread ID → message delivers fine to the main chat.

**Root causes (in order of likelihood):**

1. **Session pinned to a deleted topic** — Session IDs embed `thread_id` as part of the session key: e.g. `agent:main:telegram:dm:826307909:98791`. If the user messaged from a forum topic that was later deleted, all subsequent replies to that user retry the stale thread ID. This is the most common cause.

2. **DM topics config exists but `thread_id` is stale** — The `dm_topics` config has a `thread_id` that no longer exists in Telegram.

3. **DM topics config is non-empty but the bot lacks permission to create topics** — Hermes attempts to create or use a forum topic but the bot doesn't have "Can create forum topics" admin permission.

**Fix — three-step process (always do all three):**

```bash
# Step 1: Disable DM topics auto-creation (prevents Hermes from caching new thread IDs)
# Config path: platforms.telegram.extra.dm_topics (NOT telegram.extra.dm_topics)

# Edit config.yaml directly — add extra.dm_topics: [] under platforms.telegram:
# platforms:
#   telegram:
#     extra:
#       dm_topics: []

# Step 2: Delete stuck sessions — session files embed the stale thread_id
# Find sessions containing the bad thread ID:
grep -l "98791\|98785\|98781" ~/.hermes/sessions/session_*.json
# Delete them:
rm ~/.hermes/sessions/session_YOUR_SESSION_ID.json

# Step 3: Restart gateway to clear in-memory thread ID cache
systemctl --user restart hermes-gateway
```

**Verification:**
```bash
# After restart — no "Setting up DM topic" or "Thread N not found" at startup
tail -20 ~/.hermes/logs/gateway.log

# Send a test message from Telegram — check for warnings
grep "Thread.*not found" ~/.hermes/logs/gateway.log
```

### Config Path for dm_topics: `platforms.telegram.extra.dm_topics`

The dm_topics config lives at `config.platforms.telegram.extra.dm_topics`, NOT at `config.telegram.extra.dm_topics`. Those are different YAML paths:

```yaml
# WRONG — this path is NOT read by Hermes for dm_topics
telegram:
  extra:
    dm_topics: []

# CORRECT — lives under the platforms umbrella
platforms:
  telegram:
    extra:
      dm_topics: []
```

The top-level `telegram:` section in config.yaml holds simple settings (`reactions`, `channel_prompts`, `allowed_chats`) that Hermes reads directly. The `dm_topics` feature uses the `platforms.telegram.extra` path instead. When you add `extra.dm_topics` under the top-level `telegram:` key, Hermes does not read it for topic management — this is a common misconfiguration that causes the "Thread not found" warnings to persist even after adding `dm_topics: []`.

### Verify DM Topics Config

```bash
# Check if dm_topics is set under the correct path
grep -A5 "platforms:" ~/.hermes/config.yaml

# Check gateway logs for topic activity
grep "DM topic\|Thread.*not found\|Bot_forum_create" ~/.hermes/logs/gateway.log
```

### Automated Diagnostic Script

Run the support script to check all three failure points at once:

```bash
bash ~/.hermes/skills/messaging/telegram-group-mention-only/scripts/telegram-thread-fix.sh
# Or pass a specific thread ID:
bash ~/.hermes/skills/messaging/telegram-group-mention-only/scripts/telegram-thread-fix.sh 98791
```

## Troubleshooting

| Symptom | Likely Cause |
|---------|-------------|
| Bot never responds in groups | `require_mention: true` set but no @mention |
| Bot responds to everything in groups | `require_mention` not set or not restarted |
| Bot ignores @mention | Bot username not detected; check `_message_mentions_bot()` |
| Want it global (all groups) | Just set `require_mention: true` — no other config needed |
| "Bot_forum_create_forbidden" in logs | Bot lacks topic-creation permission; set `dm_topics: []` under `platforms.telegram.extra` |
| "Thread N not found" in logs | Session pinned to deleted topic; delete stuck sessions + restart gateway |
| Thread warnings persist after restart | dm_topics config in wrong path — must be under `platforms.telegram.extra`, not top-level `telegram:` |
