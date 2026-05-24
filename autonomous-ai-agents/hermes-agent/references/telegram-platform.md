# Telegram Platform Reference

## Thread "Not Found" Warnings

When the gateway log shows:
```
[Telegram] Thread 98785 not found, retrying without message_thread_id
```

**The retry always succeeds** — Hermes falls back to sending without `message_thread_id` and the message reaches the main chat. The warning is cosmetic but annoying. Root causes:

1. **Session pinned to a deleted forum topic** (most common) — Session IDs embed `thread_id`: `agent:main:telegram:dm:826307909:98791`. If the user sent a message from a forum topic that was later deleted, every reply tries to use the stale thread ID.
2. **Bot is not admin in the forum topic** — needs "Can manage topics" admin permission
3. **`dm_topics` config in wrong path** — Hermes reads from `platforms.telegram.extra.dm_topics`, not `telegram.extra.dm_topics`

## DM Topics Config Path

**Correct path:** `config.platforms.telegram.extra.dm_topics`

```yaml
# In config.yaml — MUST be under platforms.telegram.extra, NOT top-level telegram.extra
platforms:
  telegram:
    extra:
      dm_topics: []    # empty = disable DM topics auto-creation
      # Or with real topics:
      # dm_topics:
      #   - chat_id: 826307909
      #     topics:
      #       - name: "会话1"
      #         thread_id: 98771
```

The top-level `telegram:` section in config.yaml holds only simple settings (`reactions`, `channel_prompts`, `allowed_chats`). Adding `extra` there does NOT work — Hermes does not read `telegram.extra.dm_topics` for topic management.

## Session-Based Thread ID Caching

Hermes caches thread IDs in two places:
- **In-memory** (`self._dm_topics` dict) — cleared by `hermes gateway restart`
- **In session files** (`session_*.json`) — session key includes the thread ID; must be deleted manually

The stuck-session problem:
- Session file contained references to a stale thread (e.g. `98791`)
- Every reply from that session tried to use thread `98791`
- Even after `dm_topics: []` was set, the session still had the stale thread ID
- Fix: delete the session file + restart gateway

```bash
# Find sessions with stale thread IDs
grep -l "98791\|98785\|98781" ~/.hermes/sessions/session_*.json

# Delete them
rm ~/.hermes/sessions/session_YOUR_SESSION_ID.json

# Restart
systemctl --user restart hermes-gateway
```

## The `/start` Command

Hermes does NOT register `/start` as a slash command. Telegram bots traditionally use `/start`, but Hermes' command registry doesn't include it. Sending `/start` to the bot returns "unknown command" — **this is by design, not a bug**.

Use `/help` or just send a plain message.

## Bot_forum_create_forbidden

```
Failed to create DM topic 'Hermes' in chat 826307909: Bot_forum_create_forbidden
```

The bot tried to create a forum topic via Telegram's `createForumTopic` API but lacks the "Can create forum topics" admin permission. This happens when:
- Bot tries to auto-create a DM topic on first DM contact
- Bot is not a Telegram Premium user (required for DM forum topics in personal chats)

Fix: set `dm_topics: []` (empty) under `platforms.telegram.extra` to suppress all topic creation attempts.

## Gateway Log Quick Checks

```bash
# Thread / DM topic activity
grep -E "Thread|DM topic|Bot_forum" ~/.hermes/logs/gateway.log | tail -20

# Full gateway status
tail -30 ~/.hermes/logs/gateway.log

# Restart and watch startup
systemctl --user restart hermes-gateway && sleep 8 && tail -15 ~/.hermes/logs/gateway.log
```

