---
name: hermes-agent
description: "Configure, extend, or contribute to Hermes Agent."
version: 2.1.0
author: Hermes Agent + Teknium
license: MIT
metadata:
  hermes:
    tags: [hermes, setup, configuration, multi-agent, spawning, cli, gateway, development]
    homepage: https://github.com/NousResearch/hermes-agent
    related_skills: [claude-code, codex, opencode]
---

# Hermes Agent

Hermes Agent is an open-source AI agent framework by Nous Research that runs in your terminal, messaging platforms, and IDEs. It belongs to the same category as Claude Code (Anthropic), Codex (OpenAI), and OpenClaw — autonomous coding and task-execution agents that use tool calling to interact with your system. Hermes works with any LLM provider (OpenRouter, Anthropic, OpenAI, DeepSeek, local models, and 15+ others) and runs on Linux, macOS, and WSL.

What makes Hermes different:

- **Self-improving through skills** — Hermes learns from experience by saving reusable procedures as skills. When it solves a complex problem, discovers a workflow, or gets corrected, it can persist that knowledge as a skill document that loads into future sessions. Skills accumulate over time, making the agent better at your specific tasks and environment.
- **Persistent memory across sessions** — remembers who you are, your preferences, environment details, and lessons learned. Pluggable memory backends (built-in, Honcho, Mem0, and more) let you choose how memory works.
- **Multi-platform gateway** — the same agent runs on Telegram, Discord, Slack, WhatsApp, Signal, Matrix, Email, and 10+ other platforms with full tool access, not just chat.
- **Provider-agnostic** — swap models and providers mid-workflow without changing anything else. Credential pools rotate across multiple API keys automatically.
- **Profiles** — run multiple independent Hermes instances with isolated configs, sessions, skills, and memory.
- **Extensible** — plugins, MCP servers, custom tools, webhook triggers, cron scheduling, and the full Python ecosystem.

People use Hermes for software development, research, system administration, data analysis, content creation, home automation, and anything else that benefits from an AI agent with persistent context and full system access.

**This skill helps you work with Hermes Agent effectively** — setting it up, configuring features, spawning additional agent instances, troubleshooting issues, finding the right commands and settings, and understanding how the system works when you need to extend or contribute to it.

**Docs:** https://hermes-agent.nousresearch.com/docs/

### Verifying a Provider API Key
- `references/ai-centos-hk-endpoint.md` — CentOS HK proxy models, probe commands
- `references/deepseek-provider.md` — DeepSeek API key setup, model list, verification probe
- `references/custom-provider-yaml.md` — Custom provider YAML formats (list vs dict), `hermes config set` gotcha, valid fields, probe commands

### Built-in Provider Setup (DeepSeek, OpenAI, Anthropic, etc.)

For providers that are **first-class built-ins** (DeepSeek, OpenAI, Anthropic, Google Gemini, xAI, HuggingFace, MiniMax, Kimi, etc. — see full provider table), no `config.yaml` change is needed. Just write the API key to `~/.hermes/.env`:

```bash
# Add API key to .env (one at a time, appends to end of file)
echo "DEEPSEEK_API_KEY=sk-your-key-here" >> ~/.hermes/.env

# Verify it was saved (key will be redacted in output)
grep DEEPSEEK ~/.hermes/.env
```

Then switch to the provider in-session:
```
/model deepseek
```
or from terminal: `hermes model`

**Do NOT use `hermes config set` for built-in providers** — it is only needed for custom endpoint providers. Config changes are for `config.yaml` values; API keys belong in `.env`.

### Verifying a Provider API Key

To confirm an API key works and list available models, probe the provider's `/models` endpoint directly:

```python
python3 - << 'PY'
import json, urllib.request

KEY = "sk-your-key-here"
PROVIDER = "https://api.deepseek.com"  # or provider's base URL

req = urllib.request.Request(
    f"{PROVIDER}/v1/models",
    headers={"Authorization": f"Bearer {KEY}"}
)
with urllib.request.urlopen(req, timeout=8) as r:
    data = json.loads(r.read())

for m in data["data"]:
    print(m["id"])
PY
```

Common endpoints: DeepSeek (`https://api.deepseek.com/v1`), OpenAI (`https://api.openai.com/v1`), Anthropic (no `/v1/models` — use `hermes doctor` instead).

### Custom Provider YAML Gotcha

**`hermes config set` 写 `custom_providers` 会生成畸形 YAML。**

`hermes config set custom_providers '[{"name":"a","model":"m1"},{"name":"b","model":"m2"}]'` 会产生：
```yaml
custom_providers[1]:
  - name: a
    model: m1
custom_providers[2]:
  name: b
  model: m2
```

正确做法：用 `hermes config edit` 或直接 patch 配置文件，写成标准 YAML 列表：
```yaml
custom_providers:
  - name: a
    model: m1
  - name: b
    model: m2
```

**Two formats coexist** — legacy `custom_providers: [...]` (list) and v12+ `providers: {...}` (dict). Both work; the key used in `model.provider` differs:
- List: `custom_providers[0].name = "myProv"` → reference as `provider: custom:myProv`
- Dict: `providers.myProv` → reference as `provider: myProv` (no `custom:` prefix)

See `references/custom-provider-yaml.md` for full field reference, probe commands, and switching mid-session.

### Config Security: Moving API Keys to .env

API keys in `config.yaml` (under `model.api_key` or `custom_providers[].api_key`) are plaintext and visible to anyone with filesystem access. Move them to `~/.hermes/.env`.

**Problem:** When `security.redact_secrets: true` is enabled, `read_file` output masks keys like `sk-HzG...NVUS`. You can't copy-paste them to `.env` via normal tool output — the keys are gone from your view.

**Solution:** Use a `terminal` Python script that reads the raw config file, extracts keys via regex, and writes them to `.env` **without echoing keys to stdout**:

```bash
python3 -c "
import re
with open('$HOME/.hermes/config.yaml') as f:
    content = f.read()
keys = re.findall(r'api_key:\s*(sk-\S+)', content)
with open('$HOME/.hermes/.env', 'a') as f:
    f.write('\n# Custom Provider API Keys (moved from config.yaml)\n')
    for i, k in enumerate(keys):
        f.write(f'PROVIDER_KEY_{i}={k}\n')
print(f'OK: {len(keys)} keys extracted to .env')
"
```

Then replace `api_key: sk-xxx...` in config.yaml with `${ENV_VAR_NAME}` references:
```yaml
model:
  api_key: ${PROVIDER_KEY_0}
custom_providers:
  - name: my_provider
    api_key: ${PROVIDER_KEY_1}
```

> **Caveat:** `${VAR}` syntax may not be resolved by Hermes' config loader. If auth fails after restart, fall back to `hermes auth add` for credential pool management.

### Self-Update & Verification

**Built-in `/update` times out in terminal tool** — because the gateway restart kills the calling process. This is expected, not an error. Use `git pull` instead for reliable self-update:

See `references/self-update-verification.md` for the full procedure: record hash before → `git pull origin main` → compare hash after → restart gateway.

### Common Config Pitfalls (Quick Review)

When reviewing a Hermes `config.yaml` + `.env`, check these:

1. **API keys in config.yaml** — should live in `.env` or credential pool
2. **Auxiliary models all `auto`** — needs `OPENROUTER_API_KEY` or explicit per-task provider/model, otherwise vision/compression/search silently fail
3. **Delegation unconfigured** — `delegation.model`/`provider`/`api_key` empty → subagents don't work
4. **Terminal timeout mismatch** — `.env` `TERMINAL_TIMEOUT` overrides `config.yaml` `terminal.timeout`; check both
5. **Web/search backend empty** — `web.backend: ''` may silently degrade search quality
6. **Checkpoints disabled** — `checkpoints.enabled: false` means `/rollback` won't work
7. **Approvals `manual`** — consider `smart` for better UX (auto-approves low-risk commands)
8. **Platform UX** — `telegram.reactions`, `discord.reactions` default to `false`
9. **Updates `pre_update_backup: false`** — no rollback on bad update
10. **Display** — `show_cost: false`, `streaming: false` may reduce visibility

Config changes need gateway restart: `hermes gateway restart` or `/restart` in Telegram.

### User Preferences (Session: milvillena99 / barxhe1209)
- **默认模型不自动切换** — 添加 custom provider 时只注册到 `custom_providers[]`，不改动 `model.default`。用 `/model provider-name` 手动切换。

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# Interactive chat (default)
hermes

# Single query
hermes chat -q "What is the capital of France?"

# Setup wizard
hermes setup

# Change model/provider
hermes model

# Check health
hermes doctor
```

---

## CLI Reference

### Global Flags

```
hermes [flags] [command]

  --version, -V             Show version
  --resume, -r SESSION      Resume session by ID or title
  --continue, -c [NAME]     Resume by name, or most recent session
  --worktree, -w            Isolated git worktree mode (parallel agents)
  --skills, -s SKILL        Preload skills (comma-separate or repeat)
  --profile, -p NAME        Use a named profile
  --yolo                    Skip dangerous command approval
  --pass-session-id         Include session ID in system prompt
```

No subcommand defaults to `chat`.

### Chat

```
hermes chat [flags]
  -q, --query TEXT          Single query, non-interactive
  -m, --model MODEL         Model (e.g. anthropic/claude-sonnet-4)
  -t, --toolsets LIST       Comma-separated toolsets
  --provider PROVIDER       Force provider (openrouter, anthropic, nous, etc.)
  -v, --verbose             Verbose output
  -Q, --quiet               Suppress banner, spinner, tool previews
  --checkpoints             Enable filesystem checkpoints (/rollback)
  --source TAG              Session source tag (default: cli)
```

### Configuration

```
hermes setup [section]      Interactive wizard (model|terminal|gateway|tools|agent)
hermes model                Interactive model/provider picker
hermes config               View current config
hermes config edit          Open config.yaml in $EDITOR
hermes config set KEY VAL   Set a config value
hermes config path          Print config.yaml path
hermes config env-path      Print .env path
hermes config check         Check for missing/outdated config
hermes config migrate       Update config with new options
hermes login [--provider P] OAuth login (nous, openai-codex)
hermes logout               Clear stored auth
hermes doctor [--fix]       Check dependencies and config
hermes status [--all]       Show component status
```

### Tools & Skills

```
hermes tools                Interactive tool enable/disable (curses UI)
hermes tools list           Show all tools and status
hermes tools enable NAME    Enable a toolset
hermes tools disable NAME   Disable a toolset

hermes skills list          List installed skills
hermes skills search QUERY  Search the skills hub
hermes skills install ID    Install a skill (ID can be a hub identifier OR a direct https://…/SKILL.md URL; pass --name to override when frontmatter has no name)
hermes skills inspect ID    Preview without installing
hermes skills config        Enable/disable skills per platform
hermes skills check         Check for updates
hermes skills update        Update outdated skills
hermes skills uninstall N   Remove a hub skill
hermes skills publish PATH  Publish to registry
hermes skills browse        Browse all available skills
hermes skills tap add REPO  Add a GitHub repo as skill source
```

### MCP Servers

```
hermes mcp serve            Run Hermes as an MCP server
hermes mcp add NAME         Add an MCP server (--url or --command)
hermes mcp remove NAME      Remove an MCP server
hermes mcp list             List configured servers
hermes mcp test NAME        Test connection
hermes mcp configure NAME   Toggle tool selection
```

### Gateway (Messaging Platforms)

```
hermes gateway run          Start gateway foreground
hermes gateway install      Install as background service
hermes gateway start/stop   Control the service
hermes gateway restart      Restart the service
hermes gateway status       Check status
hermes gateway setup        Configure platforms
```

Supported platforms: Telegram, Discord, Slack, WhatsApp, Signal, Email, SMS, Matrix, Mattermost, Home Assistant, DingTalk, Feishu, WeCom, BlueBubbles (iMessage), Weixin (WeChat), API Server, Webhooks. Open WebUI connects via the API Server adapter.

Platform docs: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/

### Sessions

```
hermes sessions list        List recent sessions
hermes sessions browse      Interactive picker
hermes sessions export OUT  Export to JSONL
hermes sessions rename ID T Rename a session
hermes sessions delete ID   Delete a session
hermes sessions prune       Clean up old sessions (--older-than N days)
hermes sessions stats       Session store statistics
```

### Cron Jobs

```
hermes cron list            List jobs (--all for disabled)
hermes cron create SCHED    Create: '30m', 'every 2h', '0 9 * * *'
hermes cron edit ID         Edit schedule, prompt, delivery
hermes cron pause/resume ID Control job state
hermes cron run ID          Trigger on next tick
hermes cron remove ID       Delete a job
hermes cron status          Scheduler status
```

### Webhooks

```
hermes webhook subscribe N  Create route at /webhooks/<name>
hermes webhook list         List subscriptions
hermes webhook remove NAME  Remove a subscription
hermes webhook test NAME    Send a test POST
```

### Profiles

```bash
hermes profile list         List all profiles
hermes profile create NAME  Create (--clone, --clone-all, --clone-from)
hermes profile use NAME     Set sticky default
hermes profile delete NAME  Delete a profile
hermes profile show NAME    Show details
hermes profile alias NAME   Manage wrapper scripts
hermes profile rename A B   Rename a profile
hermes profile export NAME  Export to tar.gz
hermes profile import FILE  Import from archive
```

### Multi-Bot / Multi-Account Isolation (Gateway)

When running Hermes as a Telegram/Discord/Slack gateway with **multiple bots or accounts**, each account needs its own profile to isolate workspace, sessions, memory, and todo lists. Here's the pattern:

**What to share:** provider, model, skills
**What to isolate:** workspace, sessions, memory, todo

#### Scenario A: Multiple bots, each with its own token (full parallel isolation)

Each Telegram/Discord bot gets its own profile and gateway process. All bots can run simultaneously.

##### Setup Steps

1. **Create profiles:**

```bash
hermes profile create bot_account_a
hermes profile create bot_account_b
```

2. **Give each profile its own `config.yaml`** at `~/.hermes/profiles/<name>/config.yaml`. Copy the full root config, then override:
   - `terminal.cwd` — point to a unique workspace path per profile
   - `telegram.allowed_chats` / `telegram.allowed_users` — restrict to that account's users
   - **Do NOT copy API keys** — they stay in `.env`

3. **Per-profile `.env`** — place at `~/.hermes/profiles/<name>/.env`:
   ```bash
   TELEGRAM_BOT_TOKEN=<unique-token-for-this-bot>
   TELEGRAM_ALLOWED_USERS=<user-id-1>,<user-id-2>
   ```
   The profile inherits `DEEPSEEK_API_KEY` etc. from the root `.env` automatically.

4. **Share skills across profiles** — in each profile's `config.yaml`:
   ```yaml
   skills:
     external_dirs:
       - /home/user/.hermes/skills        # root shared skills
   ```

   ⚠️ `rm -rf` on large skills directories will **time out** in the `terminal()` tool. Use `execute_code` with `shutil.rmtree` instead:
   ```python
   import os, shutil
   shutil.rmtree("/path/to/profile/skills", ignore_errors=True)
   os.symlink("/home/user/.hermes/skills", "/path/to/profile/skills")
   ```

5. **Run separate gateway instances**, one per profile:
   ```bash
   # Terminal 1
   hermes --profile bot_account_a gateway run

   # Terminal 2
   hermes --profile bot_account_b gateway run
   ```

##### Verification

Each profile gets its own `state.db` (sessions + todo), `memories/`, and `workspace/` directory. Sessions created in one account never appear in another.

##### Pitfalls

- **Do NOT share the same bot token across profiles** — each bot needs its own token and its own gateway process.
- **Don't forget `skills.external_dirs`** — without it, each profile starts with a fresh empty skills directory.
- **Gateway instances compete for ports** — by default the API server uses port 8000. Set a different port per profile: `hermes config set gateway.api_port 8001` per-profile.
- **Systemd services need separate unit names** — use `hermes gateway install --profile <name>` to register unique service names.

#### Scenario B: Single bot, multiple Telegram users (serial isolation)

When you have **one Telegram bot** but multiple users chatting with it, and you want each user to have their own workspace/sessions/memory/todo. The constraint: only one user's profile can run at a time because Telegram only allows one gateway connection per bot token.

##### Setup Steps

1. **Create per-user profiles** (or rename existing auto-created ones):
   ```bash
   hermes profile create tg_user_123456
   hermes profile create tg_user_789012
   ```

2. **Each profile gets its own `config.yaml`** at `~/.hermes/profiles/<name>/config.yaml`:
   ```yaml
   terminal:
     cwd: /home/user/.hermes/profiles/tg_user_123456/workspace
   skills:
     external_dirs:
       - /home/user/.hermes/skills
   ```
   All other config (model, provider, etc.) can be identical across profiles.

3. **Per-profile `.env`** — place at `~/.hermes/profiles/<name>/.env`:
   ```bash
   TELEGRAM_BOT_TOKEN=<same-token-for-all>     # same bot
   TELEGRAM_ALLOWED_USERS=123456                # only this user
   TELEGRAM_HOME_CHANNEL=123456                 # this user's home
   DEEPSEEK_API_KEY=sk-...                      # or inherit from root .env
   ```
   The `TELEGRAM_ALLOWED_USERS` is the **gating mechanism** — when the gateway runs with this profile, only this user's messages are processed. Messages from other users are silently dropped.

4. **Share skills** — either via `skills.external_dirs` (as in Step 2) or by replacing the profile's `skills/` dir with a symlink to the root shared skills:
   ```python
   import os, shutil
   shutil.rmtree("/home/user/.hermes/profiles/tg_user_123456/skills", ignore_errors=True)
   os.symlink("/home/user/.hermes/skills", "/home/user/.hermes/profiles/tg_user_123456/skills")
   ```

##### Running

Only one profile can run at a time with a single bot token:

```bash
# User A's turn
hermes --profile tg_user_123456 gateway run

# Stop user A, then start user B
hermes --profile tg_user_789012 gateway run
```

Switching users means stopping and restarting the gateway with a different profile. For true parallel access, upgrade to Scenario A (separate bot tokens).

##### Key differences from Scenario A

| Aspect | Scenario A (multi-bot) | Scenario B (single-bot) |
|--------|----------------------|------------------------|
| Bot tokens | One per profile | Same token for all |
| Run simultaneously | Yes | ❌ No — one at a time |
| Isolation level | Full | Full, but serialized |
| ALLOWED_USERS | Optional (bot is user) | **Required** (gates which user) |

##### Pitfalls

- **Only one profile can run at a time** — Telegram rejects a second webhook/polling connection for the same token.
- **ALLOWED_USERS must match the profile** — if gateway runs with `tg_user_A` but `ALLOWED_USERS` includes user B, user B's messages get processed under user A's workspace, breaking isolation.
- **Missing per-profile `.env`** — the gateway falls back to root `~/.hermes/.env`, which may have the wrong ALLOWED_USERS.
- **No `state.db` on first use** — the profile's `state.db` is auto-created on first gateway run. It's normal for new profiles to have no sessions yet.

**Manual import from raw backup directory:** If you have a backup at `~/.hermes/input/` (not a `.tar.gz`), you can selectively sync subdirectories:

```bash
# Sync skills from backup
cp -r ~/.hermes/input/skills/* ~/.hermes/skills/

# Sessions are auto-discovered from ~/.hermes/sessions/ — copy to activate:
cp ~/.hermes/input/sessions/*.jsonl ~/.hermes/sessions/

# Memories: copy the memories store
cp -r ~/.hermes/input/memories/* ~/.hermes/memories/

# Config snapshot (if needed)
cp ~/.hermes/input/config.yaml ~/.hermes/config.yaml
```

> Note: `input/` (singular) is the raw backup directory name created by profile exports. The user may refer to it as `inputs` (plural) — correct the path mentally.

##### Syncing model/provider across profiles

When you have multiple profiles sharing the same model and provider (common for multi-bot or multi-user setups), changes are manual per-profile. Use the included sync script to apply model/provider changes from one source profile to all others:

```bash
# Use default source (tg_826307909) — syncs to all other profiles
python3 ~/.hermes/scripts/sync-model-provider.py

# Or specify a source profile
python3 ~/.hermes/scripts/sync-model-provider.py tg_1596476147
```

The script syncs: `model`, `custom_providers`, `fallback_providers`, `providers`, `credential_pool_strategies`. All other config (workspace, memory, skills, terminal, etc.) is left untouched.

> **Convention:** The sync script lives under the `hermes-agent` skill as `scripts/sync-model-provider.py`. It's also installed to `~/.hermes/scripts/sync-model-provider.py` for standalone use.

### Credential Pools

```
hermes auth add             Interactive credential wizard
hermes auth list [PROVIDER] List pooled credentials
hermes auth remove P INDEX  Remove by provider + index
hermes auth reset PROVIDER  Clear exhaustion status
```

### Other

```
hermes insights [--days N]  Usage analytics
hermes update               Update to latest version
hermes pairing list/approve/revoke  DM authorization
hermes plugins list/install/remove  Plugin management
hermes honcho setup/status  Honcho memory integration (requires honcho plugin)
hermes memory setup/status/off  Memory provider config
hermes completion bash|zsh  Shell completions
hermes acp                  ACP server (IDE integration)
hermes claw migrate         Migrate from OpenClaw
hermes uninstall            Uninstall Hermes
```

---

## Slash Commands (In-Session)

Type these during an interactive chat session. New commands land fairly
often; if something below looks stale, run `/help` in-session for the
authoritative list or see the [live slash commands reference](https://hermes-agent.nousresearch.com/docs/reference/slash-commands).
The registry of record is `hermes_cli/commands.py` — every consumer
(autocomplete, Telegram menu, Slack mapping, `/help`) derives from it.

### Session Control
```
/new (/reset)        Fresh session
/clear               Clear screen + new session (CLI)
/retry               Resend last message
/undo                Remove last exchange
/title [name]        Name the session
/compress            Manually compress context
/stop                Kill background processes
/rollback [N]        Restore filesystem checkpoint
/snapshot [sub]      Create or restore state snapshots of Hermes config/state (CLI)
/background <prompt> Run prompt in background
/queue <prompt>      Queue for next turn
/steer <prompt>      Inject a message after the next tool call without interrupting
/agents (/tasks)     Show active agents and running tasks
/resume [name]       Resume a named session
/goal [text|sub]     Set a standing goal Hermes works on across turns until achieved
                     (subcommands: status, pause, resume, clear)
/redraw              Force a full UI repaint (CLI)
```

### Configuration
```
/config              Show config (CLI)
/model [name]        Show or change model
/personality [name]  Set personality
/reasoning [level]   Set reasoning (none|minimal|low|medium|high|xhigh|show|hide)
/verbose             Cycle: off → new → all → verbose
/voice [on|off|tts]  Voice mode
/yolo                Toggle approval bypass
/busy [sub]          Control what Enter does while Hermes is working (CLI)
                     (subcommands: queue, steer, interrupt, status)
/indicator [style]   Pick the TUI busy-indicator style (CLI)
                     (styles: kaomoji, emoji, unicode, ascii)
/footer [on|off]     Toggle gateway runtime-metadata footer on final replies
/skin [name]         Change theme (CLI)
/statusbar           Toggle status bar (CLI)
```

### Tools & Skills
```
/tools               Manage tools (CLI)
/toolsets            List toolsets (CLI)
/skills              Search/install skills (CLI)
/skill <name>        Load a skill into session
/reload-skills       Re-scan ~/.hermes/skills/ for added/removed skills
/reload              Reload .env variables into the running session (CLI)
/reload-mcp          Reload MCP servers
/cron                Manage cron jobs (CLI)
/curator [sub]       Background skill maintenance (status, run, pin, archive, …)
/kanban [sub]        Multi-profile collaboration board (tasks, links, comments)
/plugins             List plugins (CLI)
```

### Gateway
```
/approve             Approve a pending command (gateway)
/deny                Deny a pending command (gateway)
/restart             Restart gateway (gateway)
/sethome             Set current chat as home channel (gateway)
/update              Update Hermes to latest (gateway)
/topic [sub]         Enable or inspect Telegram DM topic sessions (gateway)
/platforms (/gateway) Show platform connection status (gateway)
```

### Utility
```
/branch (/fork)      Branch the current session
/fast                Toggle priority/fast processing
/browser             Open CDP browser connection
/history             Show conversation history (CLI)
/save                Save conversation to file (CLI)
/copy [N]            Copy the last assistant response to clipboard (CLI)
/paste               Attach clipboard image (CLI)
/image               Attach local image file (CLI)
```

### Info
```
/help                Show commands
/commands [page]     Browse all commands (gateway)
/usage               Token usage
/insights [days]     Usage analytics
/gquota              Show Google Gemini Code Assist quota usage (CLI)
/status              Session info (gateway)
/profile             Active profile info
/debug               Upload debug report (system info + logs) and get shareable links
```

### Exit
```
/quit (/exit, /q)    Exit CLI
```

---

## Key Paths & Config

```
~/.hermes/config.yaml       Main configuration
~/.hermes/.env              API keys and secrets
$HERMES_HOME/skills/        Installed skills
~/.hermes/sessions/         Session transcripts
~/.hermes/logs/             Gateway and error logs
~/.hermes/auth.json         OAuth tokens and credential pools
~/.hermes/hermes-agent/     Source code (if git-installed)
```

Profiles use `~/.hermes/profiles/<name>/` with the same layout.

### Config Sections

Edit with `hermes config edit` or `hermes config set section.key value`.

| Section | Key options |
|---------|-------------|
| `model` | `default`, `provider`, `base_url`, `api_key`, `context_length` |
| `agent` | `max_turns` (90), `tool_use_enforcement` |
| `terminal` | `backend` (local/docker/ssh/modal), `cwd`, `timeout` (180) |
| `compression` | `enabled`, `threshold` (0.50), `target_ratio` (0.20) |
| `display` | `skin`, `tool_progress`, `show_reasoning`, `show_cost` |
| `stt` | `enabled`, `provider` (local/groq/openai/mistral) |
| `tts` | `provider` (edge/elevenlabs/openai/minimax/mistral/neutts) |
| `memory` | `memory_enabled`, `user_profile_enabled`, `provider` |
| `security` | `tirith_enabled`, `website_blocklist` |
| `delegation` | `model`, `provider`, `base_url`, `api_key`, `max_iterations` (50), `reasoning_effort` |
| `checkpoints` | `enabled`, `max_snapshots` (50) |

Full config reference: https://hermes-agent.nousresearch.com/docs/user-guide/configuration

### Providers

20+ providers supported. Set via `hermes model` or `hermes setup`.

| Provider | Auth | Key env var |
|----------|------|-------------|
| OpenRouter | API key | `OPENROUTER_API_KEY` |
| Anthropic | API key | `ANTHROPIC_API_KEY` |
| Nous Portal | OAuth | `hermes auth` |
| OpenAI Codex | OAuth | `hermes auth` |
| GitHub Copilot | Token | `COPILOT_GITHUB_TOKEN` |
| Google Gemini | API key | `GOOGLE_API_KEY` or `GEMINI_API_KEY` |
| DeepSeek | API key | `DEEPSEEK_API_KEY` |
| xAI / Grok | API key | `XAI_API_KEY` |
| Hugging Face | Token | `HF_TOKEN` |
| Z.AI / GLM | API key | `GLM_API_KEY` |
| MiniMax | API key | `MINIMAX_API_KEY` |
| MiniMax CN | API key | `MINIMAX_CN_API_KEY` |
| Kimi / Moonshot | API key | `KIMI_API_KEY` |
| Alibaba / DashScope | API key | `DASHSCOPE_API_KEY` |
| Xiaomi MiMo | API key | `XIAOMI_API_KEY` |
| Kilo Code | API key | `KILOCODE_API_KEY` |
| AI Gateway (Vercel) | API key | `AI_GATEWAY_API_KEY` |
| OpenCode Zen | API key | `OPENCODE_ZEN_API_KEY` |
| OpenCode Go | API key | `OPENCODE_GO_API_KEY` |
| Qwen OAuth | OAuth | `hermes login --provider qwen-oauth` |
| Custom endpoint | Config | `model.base_url` + `model.api_key` in config.yaml |
| GitHub Copilot ACP | External | `COPILOT_CLI_PATH` or Copilot CLI |

Full provider docs: https://hermes-agent.nousresearch.com/docs/integrations/providers

### Toolsets

Enable/disable via `hermes tools` (interactive) or `hermes tools enable/disable NAME`.

| Toolset | What it provides |
|---------|-----------------|
| `web` | Web search and content extraction |
| `search` | Web search only (subset of `web`) |
| `browser` | Browser automation (Browserbase, Camofox, or local Chromium) |
| `terminal` | Shell commands and process management |
| `file` | File read/write/search/patch |
| `code_execution` | Sandboxed Python execution |
| `vision` | Image analysis |
| `image_gen` | AI image generation |
| `video` | Video analysis and generation |
| `tts` | Text-to-speech |
| `skills` | Skill browsing and management |
| `memory` | Persistent cross-session memory |
| `session_search` | Search past conversations |
| `delegation` | Subagent task delegation |
| `cronjob` | Scheduled task management |
| `clarify` | Ask user clarifying questions |
| `messaging` | Cross-platform message sending |
| `todo` | In-session task planning and tracking |
| `kanban` | Multi-agent work-queue tools (gated to workers) |
| `debugging` | Extra introspection/debug tools (off by default) |
| `safe` | Minimal, low-risk toolset for locked-down sessions |
| `spotify` | Spotify playback and playlist control |
| `homeassistant` | Smart home control (off by default) |
| `discord` | Discord integration tools |
| `discord_admin` | Discord admin/moderation tools |
| `feishu_doc` | Feishu (Lark) document tools |
| `feishu_drive` | Feishu (Lark) drive tools |
| `yuanbao` | Yuanbao integration tools |
| `rl` | Reinforcement learning tools (off by default) |
| `moa` | Mixture of Agents (off by default) |

Full enumeration lives in `toolsets.py` as the `TOOLSETS` dict; `_HERMES_CORE_TOOLS` is the default bundle most platforms inherit from.

Tool changes take effect on `/reset` (new session). They do NOT apply mid-conversation to preserve prompt caching.

---

## Security & Privacy Toggles

Common "why is Hermes doing X to my output / tool calls / commands?" toggles — and the exact commands to change them. Most of these need a fresh session (`/reset` in chat, or start a new `hermes` invocation) because they're read once at startup.

### Secret redaction in tool output

Secret redaction is **off by default** — tool output (terminal stdout, `read_file`, web content, subagent summaries, etc.) passes through unmodified. If the user wants Hermes to auto-mask strings that look like API keys, tokens, and secrets before they enter the conversation context and logs:

```bash
hermes config set security.redact_secrets true       # enable globally
```

**Restart required.** `security.redact_secrets` is snapshotted at import time — toggling it mid-session (e.g. via `export HERMES_REDACT_SECRETS=true` from a tool call) will NOT take effect for the running process. Tell the user to run `hermes config set security.redact_secrets true` in a terminal, then start a new session. This is deliberate — it prevents an LLM from flipping the toggle on itself mid-task.

Disable again with:
```bash
hermes config set security.redact_secrets false
```

### PII redaction in gateway messages

Separate from secret redaction. When enabled, the gateway hashes user IDs and strips phone numbers from the session context before it reaches the model:

```bash
hermes config set privacy.redact_pii true    # enable
hermes config set privacy.redact_pii false   # disable (default)
```

### Command approval prompts

By default (`approvals.mode: manual`), Hermes prompts the user before running shell commands flagged as destructive (`rm -rf`, `git reset --hard`, etc.). The modes are:

- `manual` — always prompt (default)
- `smart` — use an auxiliary LLM to auto-approve low-risk commands, prompt on high-risk
- `off` — skip all approval prompts (equivalent to `--yolo`)

```bash
hermes config set approvals.mode smart       # recommended middle ground
hermes config set approvals.mode off         # bypass everything (not recommended)
```

Per-invocation bypass without changing config:
- `hermes --yolo …`
- `export HERMES_YOLO_MODE=1`

Note: YOLO / `approvals.mode: off` does NOT turn off secret redaction. They are independent.

### Shell hooks allowlist

Some shell-hook integrations require explicit allowlisting before they fire. Managed via `~/.hermes/shell-hooks-allowlist.json` — prompted interactively the first time a hook wants to run.

### Disabling the web/browser/image-gen tools

To keep the model away from network or media tools entirely, open `hermes tools` and toggle per-platform. Takes effect on next session (`/reset`). See the Tools & Skills section above.

---

## Voice & Transcription

### STT (Voice → Text)

Voice messages from messaging platforms are auto-transcribed.

Provider priority (auto-detected):
1. **Local faster-whisper** — free, no API key: `pip install faster-whisper`
2. **Groq Whisper** — free tier: set `GROQ_API_KEY`
3. **OpenAI Whisper** — paid: set `VOICE_TOOLS_OPENAI_KEY`
4. **Mistral Voxtral** — set `MISTRAL_API_KEY`

Config:
```yaml
stt:
  enabled: true
  provider: local        # local, groq, openai, mistral
  local:
    model: base          # tiny, base, small, medium, large-v3
```

### TTS (Text → Voice)

| Provider | Env var | Free? |
|----------|---------|-------|
| Edge TTS | None | Yes (default) |
| ElevenLabs | `ELEVENLABS_API_KEY` | Free tier |
| OpenAI | `VOICE_TOOLS_OPENAI_KEY` | Paid |
| MiniMax | `MINIMAX_API_KEY` | Paid |
| Mistral (Voxtral) | `MISTRAL_API_KEY` | Paid |
| NeuTTS (local) | None (`pip install neutts[all]` + `espeak-ng`) | Free |

Voice commands: `/voice on` (voice-to-voice), `/voice tts` (always voice), `/voice off`.

---

## Spawning Additional Hermes Instances

Run additional Hermes processes as fully independent subprocesses — separate sessions, tools, and environments.

### When to Use This vs delegate_task

| | `delegate_task` | Spawning `hermes` process |
|-|-----------------|--------------------------|
| Isolation | Separate conversation, shared process | Fully independent process |
| Duration | Minutes (bounded by parent loop) | Hours/days |
| Tool access | Subset of parent's tools | Full tool access |
| Interactive | No | Yes (PTY mode) |
| Use case | Quick parallel subtasks | Long autonomous missions |

### One-Shot Mode

```
terminal(command="hermes chat -q 'Research GRPO papers and write summary to ~/research/grpo.md'", timeout=300)

# Background for long tasks:
terminal(command="hermes chat -q 'Set up CI/CD for ~/myapp'", background=true)
```

### Interactive PTY Mode (via tmux)

Hermes uses prompt_toolkit, which requires a real terminal. Use tmux for interactive spawning:

```
# Start
terminal(command="tmux new-session -d -s agent1 -x 120 -y 40 'hermes'", timeout=10)

# Wait for startup, then send a message
terminal(command="sleep 8 && tmux send-keys -t agent1 'Build a FastAPI auth service' Enter", timeout=15)

# Read output
terminal(command="sleep 20 && tmux capture-pane -t agent1 -p", timeout=5)

# Send follow-up
terminal(command="tmux send-keys -t agent1 'Add rate limiting middleware' Enter", timeout=5)

# Exit
terminal(command="tmux send-keys -t agent1 '/exit' Enter && sleep 2 && tmux kill-session -t agent1", timeout=10)
```

### Multi-Agent Coordination

```
# Agent A: backend
terminal(command="tmux new-session -d -s backend -x 120 -y 40 'hermes -w'", timeout=10)
terminal(command="sleep 8 && tmux send-keys -t backend 'Build REST API for user management' Enter", timeout=15)

# Agent B: frontend
terminal(command="tmux new-session -d -s frontend -x 120 -y 40 'hermes -w'", timeout=10)
terminal(command="sleep 8 && tmux send-keys -t frontend 'Build React dashboard for user management' Enter", timeout=15)

# Check progress, relay context between them
terminal(command="tmux capture-pane -t backend -p | tail -30", timeout=5)
terminal(command="tmux send-keys -t frontend 'Here is the API schema from the backend agent: ...' Enter", timeout=5)
```

### Session Resume

```
# Resume most recent session
terminal(command="tmux new-session -d -s resumed 'hermes --continue'", timeout=10)

# Resume specific session
terminal(command="tmux new-session -d -s resumed 'hermes --resume 20260225_143052_a1b2c3'", timeout=10)
```

### Tips

- **Prefer `delegate_task` for quick subtasks** — less overhead than spawning a full process
- **Use `-w` (worktree mode)** when spawning agents that edit code — prevents git conflicts
- **Set timeouts** for one-shot mode — complex tasks can take 5-10 minutes
- **Use `hermes chat -q` for fire-and-forget** — no PTY needed
- **Use tmux for interactive sessions** — raw PTY mode has `\r` vs `\n` issues with prompt_toolkit
- **For scheduled tasks**, use the `cronjob` tool instead of spawning — handles delivery and retry

---

## Durable & Background Systems

Four systems run alongside the main conversation loop. Quick reference
here; full developer notes live in `AGENTS.md`, user-facing docs under
`website/docs/user-guide/features/`.

### Delegation (`delegate_task`)

Synchronous subagent spawn — the parent waits for the child's summary
before continuing its own loop. Isolated context + terminal session.

- **Single:** `delegate_task(goal, context, toolsets)`.
- **Batch:** `delegate_task(tasks=[{goal, ...}, ...])` runs children in
  parallel, capped by `delegation.max_concurrent_children` (default 3).
- **Roles:** `leaf` (default; cannot re-delegate) vs `orchestrator`
  (can spawn its own workers, bounded by `delegation.max_spawn_depth`).
- **Not durable.** If the parent is interrupted, the child is
  cancelled. For work that must outlive the turn, use `cronjob` or
  `terminal(background=True, notify_on_complete=True)`.

Config: `delegation.*` in `config.yaml`.

### Cron (scheduled jobs)

Durable scheduler — `cron/jobs.py` + `cron/scheduler.py`. Drive it via
the `cronjob` tool, the `hermes cron` CLI (`list`, `add`, `edit`,
`pause`, `resume`, `run`, `remove`), or the `/cron` slash command.

- **Schedules:** duration (`"30m"`, `"2h"`), "every" phrase
  (`"every monday 9am"`), 5-field cron (`"0 9 * * *"`), or ISO timestamp.
- **Per-job knobs:** `skills`, `model`/`provider` override, `script`
  (pre-run data collection; `no_agent=True` makes the script the whole
  job), `context_from` (chain job A's output into job B), `workdir`
  (run in a specific dir with its `AGENTS.md` / `CLAUDE.md` loaded),
  multi-platform delivery.
- **Invariants:** 3-minute hard interrupt per run, `.tick.lock` file
  prevents duplicate ticks across processes, cron sessions pass
  `skip_memory=True` by default, and cron deliveries are framed with a
  header/footer instead of being mirrored into the target gateway
  session (keeps role alternation intact).

User docs: https://hermes-agent.nousresearch.com/docs/user-guide/features/cron

### Curator (skill lifecycle)

Background maintenance for agent-created skills. Tracks usage, marks
idle skills stale, archives stale ones, keeps a pre-run tar.gz backup
so nothing is lost.

- **CLI:** `hermes curator <verb>` — `status`, `run`, `pause`, `resume`,
  `pin`, `unpin`, `archive`, `restore`, `prune`, `backup`, `rollback`.
- **Slash:** `/curator <subcommand>` mirrors the CLI.
- **Scope:** only touches skills with `created_by: "agent"` provenance.
  Bundled + hub-installed skills are off-limits. **Never deletes** —
  max destructive action is archive. Pinned skills are exempt from
  every auto-transition and every LLM review pass.
- **Telemetry:** sidecar at `~/.hermes/skills/.usage.json` holds
  per-skill `use_count`, `view_count`, `patch_count`,
  `last_activity_at`, `state`, `pinned`.

Config: `curator.*` (`enabled`, `interval_hours`, `min_idle_hours`,
`stale_after_days`, `archive_after_days`, `backup.*`).
User docs: https://hermes-agent.nousresearch.com/docs/user-guide/features/curator

### Kanban (multi-agent work queue)

Durable SQLite board for multi-profile / multi-worker collaboration.
Users drive it via `hermes kanban <verb>`; dispatcher-spawned workers
see a focused `kanban_*` toolset gated by `HERMES_KANBAN_TASK` so the
schema footprint is zero outside worker processes.

- **CLI verbs (common):** `init`, `create`, `list` (alias `ls`),
  `show`, `assign`, `link`, `unlink`, `comment`, `complete`, `block`,
  `unblock`, `archive`, `tail`. Less common: `watch`, `stats`, `runs`,
  `log`, `dispatch`, `daemon`, `gc`.
- **Worker toolset:** `kanban_show`, `kanban_complete`, `kanban_block`,
  `kanban_heartbeat`, `kanban_comment`, `kanban_create`, `kanban_link`.
- **Dispatcher** runs inside the gateway by default
  (`kanban.dispatch_in_gateway: true`) — reclaims stale claims,
  promotes ready tasks, atomically claims, spawns assigned profiles.
  Auto-blocks a task after ~5 consecutive spawn failures.
- **Isolation:** board is the hard boundary (workers get
  `HERMES_KANBAN_BOARD` pinned in env); tenant is a soft namespace
  within a board for workspace-path + memory-key isolation.

User docs: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban

---

## Troubleshooting

### CPU 100% — cpulimit death spiral

**Symptom:** `top` shows 0% idle, load average >50 on a 2-core VM, dozens/hundreds of `cpulimit` and `apport` processes.

**Root cause:** The `hermes-cpulimit.sh` script uses `cpulimit -p <PID> -l <limit> -b -m -q` in a polling loop. The `-b` flag creates a **new** background monitoring process each iteration without killing old ones. Over time:
1. Cpulimit processes accumulate (one per poll cycle)
2. Old instances crash/conflict → trigger **apport** (Ubuntu crash reporter)
3. Apport collects crash dumps (CPU-intensive) → spawns MORE cpulimit
4. **Death spiral** — CPU completely consumed by cpulimit + apport, leaving none for the target process

**Immediate fix:**
```bash
sudo systemctl stop hermes-cpulimit.service    # stop the script
sudo systemctl disable hermes-cpulimit.service  # prevent auto-start
sudo killall -9 cpulimit apport                 # kill all runaway processes
sudo systemctl disable --now apport             # optional: disable apport entirely
# Verify: top shows normal CPU usage again
```

**Root fix — update `scripts/hermes-cpulimit.sh`:** Track cpulimit PIDs and kill old instances before spawning new ones. See the updated version of this script at `scripts/hermes-cpulimit.sh` — it now stores PIDs in a file and kills stale ones on each poll cycle.

**Better alternatives (preferred over cpulimit):**
- **`nice` / `renice`** — lower the scheduling priority of the target process so other processes get CPU first, no monitoring daemon needed:
  ```bash
  renice -n 10 -p $(pgrep -f "hermes_cli.*gateway")
  ```
- **`systemd-run --scope` with `CPUQuota`** — hard CPU cap via cgroups, no polling:
  ```bash
  systemd-run --scope -p CPUQuota=80% -p MemoryMax=512M \
    -u hermes-scope --user \
    /path/to/python -m hermes_cli.main gateway run
  ```
  This limits the process group to 80% of one core, enforced by the kernel. Survives restarts via systemd service, no monitoring needed.

### Voice not working
1. Check `stt.enabled: true` in config.yaml
2. Verify provider: `pip install faster-whisper` or set API key
3. In gateway: `/restart`. In CLI: exit and relaunch.

### Tool not available
1. `hermes tools` — check if toolset is enabled for your platform
2. Some tools need env vars (check `.env`)
3. `/reset` after enabling tools

### Model/provider issues
1. `hermes doctor` — check config and dependencies
2. `hermes login` — re-authenticate OAuth providers
3. Check `.env` has the right API key
4. **Copilot 403**: `gh auth login` tokens do NOT work for Copilot API. You must use the Copilot-specific OAuth device code flow via `hermes model` → GitHub Copilot.

### Changes not taking effect
- **Tools/skills:** `/reset` starts a new session with updated toolset
- **Config changes:** In gateway: `/restart`. In CLI: exit and relaunch.
- **Code changes:** Restart the CLI or gateway process

### Skills not showing
1. `hermes skills list` — verify installed
2. `hermes skills config` — check platform enablement
3. Load explicitly: `/skill name` or `hermes -s name`

### Gateway issues
Check logs first:
```bash
grep -i "failed to send\|error" ~/.hermes/logs/gateway.log | tail -20
```

Common gateway problems:
- **Gateway dies on SSH logout**: Enable linger: `sudo loginctl enable-linger $USER`
- **Gateway dies on WSL2 close**: WSL2 requires `systemd=true` in `/etc/wsl.conf` for systemd services to work. Without it, gateway falls back to `nohup` (dies when session closes).
- **Gateway crash loop**: Reset the failed state: `systemctl --user reset-failed hermes-gateway`

### Service status monitoring

For deployments with a gateway + WebUI + reverse proxy (Caddy), set up automatic health monitoring that detects gateway restarts and reports all service states.

**Recommended setup — two scripts + one cron job:**

1. **`scripts/check-hermes-status.sh`** — Standalone status check that probes all services:
   - Gateway (reads `gateway.pid`, checks process is alive)
   - WebUI (checks port 8787 via `ss -tlnp`)
   - Caddy (port 2080 + `systemctl is-active caddy`)
   - Cron jobs (reads `cron/jobs.json`)
   - Profiles (lists `profiles/` directories)
   - Disk usage

2. **`scripts/gateway-watchdog.sh`** — Gateway restart detector. Compares the current gateway PID against a stored value (`~/.hermes/.gateway_last_pid`). Silent when PID is unchanged; prints a full status report when PID changes (indicating a restart).

3. **No-agent cron job** — Runs the watchdog every 1-2 minutes:
   ```
   Schedule: every 2m
   Script: gateway-watchdog.sh
   no_agent: true
   Deliver: origin (sends to the chat that created the job)
   ```
   When the gateway restarts (e.g. after `/restart` or config change), the watchdog detects the PID change within 2 minutes and delivers the status report automatically.

**Why this works:** The `gateway.pid` file at `~/.hermes/gateway.pid` contains a JSON object with `pid`, `kind`, `start_time`, and `argv`. It's updated whenever the gateway process starts. The watchdog reads this, extracts the PID, and compares it to the last known value stored in `~/.hermes/.gateway_last_pid`.

**Pitfalls:**
- Initialize `~/.hermes/.gateway_last_pid` with the current PID to avoid a false-positive on the first cron run
- The cron job must use `no_agent: true` — it's a bash script, not an agent task
- `deliver: local` means the output is written to the cron output dir but not sent to any chat — use `deliver: origin` to get Telegram notifications
- If the gateway process dies but the PID file isn't cleaned up, the watchdog may miss the outage (the `kill -0` check catches stale PIDs where the process is truly dead but the file lingers)

### Backup & Recovery

For deployments using **Profiles** (multi-user isolation), the root-level backup must also cover per-profile data. A simple `cp -r ~/.hermes/` misses the profile directories and their independent sessions, memories, and cron jobs.

**Recommended approach — profile-aware backup script:**

Save to `~/.hermes/scripts/backup_hermes.sh` (also available under this skill as `scripts/backup_hermes.sh`):

1. **Backup order** — smallest first to avoid timeout on large skills dirs:
   - Root core files (config.yaml, .env, kanban.db, gateway_state.json, etc.)
   - Profiles directory (each profile's config.yaml, SOUL.md, cron, memories, sessions, plans, workspace)
   - Root data dirs (sessions, memories, cron)
   - Skills directory (largest — copied last)

2. **Retention** — keeps 7 days of backups in `~/.hermes/bk/`, automatically prunes older ones.

3. **What gets backed up per profile:**
   ```
   profiles/<name>/
   ├── config.yaml      # profile-specific config
   ├── SOUL.md          # personality
   ├── cron/            # per-profile cron jobs
   ├── memories/        # per-profile memory store
   ├── sessions/        # per-profile session history
   ├── plans/           # per-profile plan files
   └── workspace/       # per-profile workspace files
   ```

4. **What is NOT backed up per profile:**
   - `skills/` — symlinked to root shared skills (already backed up at root level)
   - `home/`, `logs/`, `skins/`, `webui_state/` — transient/recreatable

**Setup as a cron job:**
```yaml
Schedule: 0 23 * * *   # every day at 23:00
Script: backup_hermes.sh
no_agent: true
Deliver: local
```

**Verification:** After the backup runs, check:
```bash
# Latest backup exists
ls -lt ~/.hermes/bk/ | head -3

# All expected content present
ls ~/.hermes/bk/backup_$(date +%Y%m%d)*/profiles/

# Total size
du -sh ~/.hermes/bk/
```

**Pitfalls:**
- `cp -a` with verbose output (`-v`) on the skills directory generates thousands of lines that may time out the terminal tool. The script above uses `cp -a` without `-v` for skills to stay fast.
- The `set -e` in the script means any failed `cp` aborts the whole backup. Each `cp` should use `|| true` if the source may not exist (e.g., profile subdirectories that haven't been created yet for new profiles).
- Backup target `~/.hermes/bk/` is excluded from profile iteration (`[ "$name" = "bk" ] && continue`) to avoid recursive self-backup.

### Platform-specific issues
- **Telegram `/start` not recognized**: By design — `/start` is not in Hermes' command registry. Use `/help` or a plain message instead. See `references/telegram-platform.md`.
- **Telegram "Thread not found" warnings**: Bot lacks admin permission to manage forum topics, or topic was deleted. See `references/telegram-platform.md`.
- **Discord bot silent**: Must enable **Message Content Intent** in Bot → Privileged Gateway Intents.
- **Slack bot only works in DMs**: Must subscribe to `message.channels` event. Without it, the bot ignores public channels.
- **Windows HTTP 400 "No models provided"**: Config file encoding issue (BOM). Ensure `config.yaml` is saved as UTF-8 without BOM.

### Auxiliary models not working
If `auxiliary` tasks (vision, compression, session_search) fail silently, the `auto` provider can't find a backend. Either set `OPENROUTER_API_KEY` or `GOOGLE_API_KEY`, or explicitly configure each auxiliary task's provider:
```bash
hermes config set auxiliary.vision.provider <your_provider>
hermes config set auxiliary.vision.model <model_name>
```

---

### WebUI

Hermes Agent includes a web dashboard served by `hermes-webui/server.py`.

```bash
# Default port: 8787 (binds to 127.0.0.1)
# HOST/PORT overrides: HERMES_WEBUI_HOST, HERMES_WEBUI_PORT env vars
# Config source: api/config.py → HOST = os.getenv("HERMES_WEBUI_HOST", "127.0.0.1")
#                                    PORT = int(os.getenv("HERMES_WEBUI_PORT", "8787"))
```

**WebUI auth and credential recovery:** See `references/webui-auth-profiles.md` for full details on single-password vs multi-user modes. Quick diagnosis:

```bash
# Check auth status via API
curl -s http://127.0.0.1:8787/api/auth/status

# Check auth modes
cat ~/.hermes/webui/users.json 2>/dev/null  # multi-user accounts
cat ~/.hermes/webui/settings.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('password_hash:', d.get('password_hash'))"

# Check env var in running process
cat /proc/$(pgrep -f "server\\.py" | head -1)/environ 2>/dev/null | tr '\0' '\n' | grep HERMES_WEBUI_PASSWORD || echo "not set"

# Verify login (multi-user)
curl -s -X POST http://127.0.0.1:8787/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"<telegram_id>","password":"<password>"}'

# Reset password (multi-user) — remove then add
cd ~/hermes-webui
python3 scripts/manage_users.py remove <username>
python3 -c "from api.users import add_user; add_user('<username>', '<new-password>', profile='tg_<username>')"
```

**Check if running:**
```bash
ss -tlnp | grep 8787 && curl -s -o /dev/null -w "HTTP %{http_code}\\n" http://127.0.0.1:8787/
```

**Start WebUI in background (persistent):**
```bash
# Use terminal(background=true) — the process must survive beyond the tool call
# The server.py process may die unexpectedly — monitor and restart if needed
cd ~/hermes-webui && exec ~/.hermes/hermes-agent/venv/bin/python server.py 2>&1
# Then verify: ss -tlnp | grep 8787
```

**Recommended: set up the watchdog cron job** (see "Process keepalive" below) to automatically restart WebUI and Caddy when they die. Without it, expect to restart both every time you come back to a session.

**Connecting to Hermes Agent:** WebUI connects via the API Server adapter (gateway, separate from the webui server itself). Start the gateway first (`python -m hermes_cli.main gateway run --replace`), then access WebUI at port 8787.

**Settings backup:** Settings from `~/.hermes/input/webui/settings.json` can be restored:
```bash
mkdir -p ~/.hermes/webui
cp ~/.hermes/input/webui/settings.json ~/.hermes/webui/
```

**Process keepalive (no-sudo, no-systemd environments):**

WebUI and Caddy processes may die unexpectedly (between session turns, after SSH disconnect, etc.). For environments without sudo/systemd (GCP VMs, containers), use a user-level cron-based watchdog:

```bash
# Create watchdog script
cat > ~/webui-watchdog.sh << 'WATCHDOG'
#!/bin/bash
# Check WebUI
if ! curl -sf http://127.0.0.1:8787/ >/dev/null 2>&1; then
    cd ~/hermes-webui || exit 1
    nohup ~/.hermes/hermes-agent/venv/bin/python server.py > ~/webui.log 2>&1 &
    echo "WebUI restarted at $(date)" >> ~/webui-watchdog.log
fi
# Check Caddy (only if Caddyfile exists)
CADDY_BIN="$HOME/.local/bin/caddy"
CADDYFILE="$HOME/Caddyfile"
if [ -f "$CADDYFILE" ] && ! curl -sf http://127.0.0.1:2080/ >/dev/null 2>&1; then
    if [ -f "$CADDY_BIN" ]; then
        nohup "$CADDY_BIN" run --config "$CADDYFILE" > ~/caddy.log 2>&1 &
        echo "Caddy restarted at $(date)" >> ~/webui-watchdog.log
    fi
fi
WATCHDOG
chmod +x ~/webui-watchdog.sh

# Add to cron (runs every 3 minutes)
(crontab -l 2>/dev/null; echo "*/3 * * * * $HOME/webui-watchdog.sh") | crontab -
```

This ensures both services auto-recover without manual intervention. Does not require sudo.

**Hermes cron-based watchdog (preferred, if Hermes cron is available):**  \nUse the `cronjob` tool instead of system crontab. Same script, managed by Hermes:\n```\nCron: every 2m, script: webui-watchdog.sh, no_agent: true\n```\nThis keeps all scheduling inside Hermes and is visible via `hermes cron list`.\n\nHere is the production-ready watchdog script. Save to `~/.hermes/scripts/webui-watchdog.sh` — it handles BOTH user-level Caddy (in `~/.local/bin/` or elsewhere) AND system Caddy (via `systemctl restart`), with proper PID file management and error logging:\n\n```bash\n#!/usr/bin/env bash\nset -euo pipefail\n\nPIDFILE=\"/home/$USER/.hermes/webui/watchdog.pid\"\nLOG=\"/home/$USER/.hermes/webui/watchdog.log\"\nWEBUI_DIR=\"$HOME/hermes-webui\"\nVENV_PYTHON=\"$HOME/.hermes/hermes-agent/venv/bin/python\"\nCADDY_BIN=\"$HOME/.local/bin/caddy\"\nCADDYFILE=\"$HOME/Caddyfile\"\n\nmkdir -p \"$(dirname \"$LOG\")\"\n\nif [ -f \"$PIDFILE\" ] && kill -0 \"$(cat \"$PIDFILE\")\" 2>/dev/null; then\n    exit 0\nfi\necho $$ > \"$PIDFILE\"\ntrap 'rm -f \"$PIDFILE\"' EXIT\n\nlog() { echo \"[$(date '+%Y-%m-%d %H:%M:%S')] $*\" >> \"$LOG\"; }\n\ncheck_webui() { curl -sf -o /dev/null http://127.0.0.1:8787/ 2>/dev/null; }\ncheck_caddy_proxy() { curl -sf -o /dev/null http://127.0.0.1:2080/ 2>/dev/null; }\n\nrestart_webui() {\n    log \"[WEBUI] stopping...\"\n    pkill -f \"server\\.py\" 2>/dev/null || true\n    sleep 1\n    log \"[WEBUI] starting...\"\n    nohup \"$VENV_PYTHON\" \"$WEBUI_DIR/server.py\" > /dev/null 2>&1 &\n    sleep 3\n    if check_webui; then log \"[WEBUI] OK\"; else log \"[WEBUI] FAILED\"; fi\n}\n\nrestart_caddy() {\n    if systemctl is-active caddy >/dev/null 2>&1; then\n        log \"[CADDY] using systemctl restart...\"\n        systemctl restart caddy 2>/dev/null || true\n    elif [ -f \"$CADDY_BIN\" ] && [ -f \"$CADDYFILE\" ]; then\n        log \"[CADDY] user-level restart...\"\n        pkill -f \"caddy run\" 2>/dev/null || true\n        sleep 1\n        nohup \"$CADDY_BIN\" run --config \"$CADDYFILE\" > /dev/null 2>&1 &\n    else\n        log \"[CADDY] no caddy found to restart\"\n        return\n    fi\n    sleep 2\n    if check_caddy_proxy; then log \"[CADDY] OK\"; else log \"[CADDY] FAILED\"; fi\n}\n\nif ! check_webui; then log \"[WEBUI] dead, restarting\"; restart_webui; else log \"[WEBUI] OK\"; fi\nif ! check_caddy_proxy; then log \"[CADDY] dead, restarting\"; restart_caddy; else log \"[CADDY] OK\"; fi\n```

⚠️ **Background terminal exec:** When starting WebUI or Caddy with `terminal(background=true)`, prefix the command with `exec` to avoid a wrapping bash process that lingers:
```bash
# GOOD — shell is replaced by the python process
exec ~/.hermes/hermes-agent/venv/bin/python ~/hermes-webui/server.py 2>&1

# BAD — a bash process sticks around as parent
~/hermes-webui/server.py &
```
Always verify after starting: `ss -tlnp | grep PORT` AND `curl localhost:PORT`.

⚠️ **/tmp volatility (critical):** `/tmp` is NOT just cleared on reboot — it can be cleaned **between consecutive agent tool calls within the same session** (systemd `tmpfiles.d`, aggressive tmpwatch, or just a transient filesystem). **Never assume anything in `/tmp` survives from one tool call to the next.** Always install tools persistently to `~/.local/bin/` or another non-ephemeral path.

⚠️ **WebUI silently fails "Address already in use":** The most common WebUI startup failure is a stale process holding port 8787. The error (`[Errno 98] Address already in use`) often appears without `ss` showing the port because a zombie process acquired it between `ss` and the bind attempt. **Diagnosis pattern:** `ss -tlnp | grep 8787` shows nothing, but `fuser 8787/tcp` or `lsof -i :8787` reveals the PID. If curl returns HTTP 000 and the foreground test shows "Address already in use", kill the old process with `pkill -f "server\.py"` and retry. Always verify after starting with BOTH `ss -tlnp | grep PORT` AND `curl localhost:PORT`.

⚠️ **Check for pre-installed Caddy FIRST:** Before downloading any Caddy binary, always check if Caddy is already installed system-wide:\n```bash\nwhich caddy && caddy version && systemctl is-active caddy 2>/dev/null || echo \"check return=$?\"\n```\nIf `which caddy` returns `/usr/bin/caddy` and `systemctl is-active caddy` returns `active`, use the system Caddy — it's systemd-managed, auto-restarts on boot, and survives reboot without any watchdog. Only download your own copy if there is no system Caddy installed.

**System-installed Caddy (sudo available, already installed):**  \n   When Caddy was installed via `apt` and runs as a systemd service on port 80, add WebUI reverse proxy to the existing config:  \n   ```bash\n   # Edit /etc/caddy/Caddyfile — add a new site block for WebUI\n   cat >> /etc/caddy/Caddyfile << 'EOF'\n   \n   :2080 {\n       reverse_proxy localhost:8787\n       encode gzip\n   }\n   EOF\n   sudo systemctl reload caddy\n   ```
   Then access via `http://<public-ip>:2080`. Caddy auto-restarts on system boot via systemd — no manual watchdog needed for Caddy itself.  
   ⚠️ Still open GCP firewall for port 2080. No HTTPS without a domain.

Cloudflare quick tunnels (`cloudflared tunnel --url`) often fail with HTTP 530 in GCP environments due to outbound UDP/QUIC restrictions. **Directly exposing port 8787 is insecure** — WebUI has no built-in auth. Always use a reverse proxy with authentication.

1. **Caddy + domain (recommended for production, root mode):**
   ```bash
   sudo apt install -y caddy
   ```
   Configure `/etc/Caddyfile`:
   ```
   your-domain.com {
       reverse_proxy localhost:8787
       basicauth /* {
           your-user JEQf8nNhHTHkCuI8n...
       }
   }
   ```
   ```bash
   sudo caddy fmt --overwrite && sudo systemctl restart caddy
   ```
   Caddy auto-provisions HTTPS via Let's Encrypt.

2. **Caddy + no-sudo mode (no root, no domain):**
   When you don't have sudo (e.g. GCP VM without `gcloud` permissions), download Caddy and run it on a non-privileged port:
   ```bash
   # Download (save to non-ephemeral path — /tmp gets cleaned!)
   mkdir -p ~/.local/bin
   curl -sL "https://github.com/caddyserver/caddy/releases/download/v2.9.1/caddy_2.9.1_linux_amd64.tar.gz" -o /tmp/caddy.tar.gz
   cd /tmp && tar xf caddy.tar.gz && mv caddy ~/.local/bin/ && chmod +x ~/.local/bin/caddy
   rm -f /tmp/caddy.tar.gz

   # Caddyfile (port 2080 — any port >1024 works without root)
   cat > ~/Caddyfile << 'EOF'
   :2080 {
       reverse_proxy 127.0.0.1:8787
       encode gzip
   }
   EOF

   # Start in background
   exec ~/.local/bin/caddy run --config ~/Caddyfile 2>&1

   # Verify
   curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:2080/
   ```
   Then open GCP firewall for port 2080 and access via `http://<public-ip>:2080`.
   ⚠️ No HTTPS without a domain + TLS cert. Consider pairing with Cloudflare Tunnel or ngrok for TLS.

3. **ngrok (quick dev access):**
   ```bash
   ngrok http 8787
   ```
   Get the public URL from ngrok output. No auth on ngrok URL — use only for development.

4. **SSH tunnel (temporary, no external exposure):**
   From your local machine:
   ```bash
   ssh -L 8787:localhost:8787 user@your-server
   ```
   Then access `http://localhost:8787` locally.

5. **GCP Firewall Rules (if you have console access):**
   - Add ingress rule: allow TCP:8787 or TCP:2080 from 0.0.0.0/0
   - Access via `{public-ip}:8787`
   - ⚠️ Only do this behind a reverse proxy with HTTP Basic Auth — never expose raw

**Process persistence pitfalls:**  
- Caddy in `/tmp` gets cleared on reboot or after time — always install to `~/.local/bin/`; **better**: use system Caddy via `apt install caddy` (systemd-managed, survives reboot)  
- WebUI `server.py` may crash silently if gateway watcher fails or port is already in use — always check `ss -tlnp | grep 8787` after starting  
- When using `terminal(background=true)`, prefix with `exec` to avoid a wrapping shell process  
- After starting, always verify with `ss -tlnp | grep PORT` AND `curl localhost:PORT`  
- `/tmp` may be cleaned between consecutive agent tool calls — never rely on files there persisting

**GCP-specific pitfall:** The GCP metadata service blocks some tunnel tools. If Cloudflare/ngrok fail, use Caddy with a domain or SSH tunnel instead. Cloudflared specifically fails with HTTP 530 in this environment.

Note: The WebUI dev server (port 5173) referenced in some older docs refers to the optional Vite dev server for WebUI development, not the production `hermes-webui` server which runs on 8787.

For the WebUI auth + profile isolation architecture (cookie-based TLS context, single-password vs multi-user gap, per-request profile switching), see `references/webui-auth-profiles.md`.

---

## Where to Find Things

| Looking for... | Location |
|----------------|----------|
| Config options | `hermes config edit` or [Configuration docs](https://hermes-agent.nousresearch.com/docs/user-guide/configuration) |
| Available tools | `hermes tools list` or [Tools reference](https://hermes-agent.nousresearch.com/docs/reference/tools-reference) |
| Slash commands | `/help` in session or [Slash commands reference](https://hermes-agent.nousresearch.com/docs/reference/slash-commands) |
| Skills catalog | `hermes skills browse` or [Skills catalog](https://hermes-agent.nousresearch.com/docs/reference/skills-catalog) |
| Provider setup | `hermes model` or [Providers guide](https://hermes-agent.nousresearch.com/docs/integrations/providers) |
| Platform setup | `hermes gateway setup` or [Messaging docs](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/) |
| MCP servers | `hermes mcp list` or [MCP guide](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp) |
| Profiles | `hermes profile list` or [Profiles docs](https://hermes-agent.nousresearch.com/docs/user-guide/profiles) |
| Cron jobs | `hermes cron list` or [Cron docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron) |
| Memory | `hermes memory status` or [Memory docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory) |
| Env variables | `hermes config env-path` or [Env vars reference](https://hermes-agent.nousresearch.com/docs/reference/environment-variables) |
| CLI commands | `hermes --help` or [CLI reference](https://hermes-agent.nousresearch.com/docs/reference/cli-commands) |
| Gateway logs | `~/.hermes/logs/gateway.log` |
| Session files | `~/.hermes/sessions/` or `hermes sessions browse` |
| Source code | `~/.hermes/hermes-agent/` |

---

## Contributor Quick Reference

For occasional contributors and PR authors. Full developer docs: https://hermes-agent.nousresearch.com/docs/developer-guide/

### Project Layout

```
hermes-agent/
├── run_agent.py          # AIAgent — core conversation loop
├── model_tools.py        # Tool discovery and dispatch
├── toolsets.py           # Toolset definitions
├── cli.py                # Interactive CLI (HermesCLI)
├── hermes_state.py       # SQLite session store
├── agent/                # Prompt builder, context compression, memory, model routing, credential pooling, skill dispatch
├── hermes_cli/           # CLI subcommands, config, setup, commands
│   ├── commands.py       # Slash command registry (CommandDef)
│   ├── config.py         # DEFAULT_CONFIG, env var definitions
│   └── main.py           # CLI entry point and argparse
├── tools/                # One file per tool
│   └── registry.py       # Central tool registry
├── gateway/              # Messaging gateway
│   └── platforms/        # Platform adapters (telegram, discord, etc.)
├── cron/                 # Job scheduler
├── tests/                # ~3000 pytest tests
└── website/              # Docusaurus docs site
```

Config: `~/.hermes/config.yaml` (settings), `~/.hermes/.env` (API keys).

### Adding a Tool (3 files)

**1. Create `tools/your_tool.py`:**
```python
import json, os
from tools.registry import registry

def check_requirements() -> bool:
    return bool(os.getenv("EXAMPLE_API_KEY"))

def example_tool(param: str, task_id: str = None) -> str:
    return json.dumps({"success": True, "data": "..."})

registry.register(
    name="example_tool",
    toolset="example",
    schema={"name": "example_tool", "description": "...", "parameters": {...}},
    handler=lambda args, **kw: example_tool(
        param=args.get("param", ""), task_id=kw.get("task_id")),
    check_fn=check_requirements,
    requires_env=["EXAMPLE_API_KEY"],
)
```

**2. Add to `toolsets.py`** → `_HERMES_CORE_TOOLS` list.

Auto-discovery: any `tools/*.py` file with a top-level `registry.register()` call is imported automatically — no manual list needed.

All handlers must return JSON strings. Use `get_hermes_home()` for paths, never hardcode `~/.hermes`.

### Adding a Slash Command

1. Add `CommandDef` to `COMMAND_REGISTRY` in `hermes_cli/commands.py`
2. Add handler in `cli.py` → `process_command()`
3. (Optional) Add gateway handler in `gateway/run.py`

All consumers (help text, autocomplete, Telegram menu, Slack mapping) derive from the central registry automatically.

### Agent Loop (High Level)

```
run_conversation():
  1. Build system prompt
  2. Loop while iterations < max:
     a. Call LLM (OpenAI-format messages + tool schemas)
     b. If tool_calls → dispatch each via handle_function_call() → append results → continue
     c. If text response → return
  3. Context compression triggers automatically near token limit
```

### Testing

```bash
python -m pytest tests/ -o 'addopts=' -q   # Full suite
python -m pytest tests/tools/ -q            # Specific area
```

- Tests auto-redirect `HERMES_HOME` to temp dirs — never touch real `~/.hermes/`
- Run full suite before pushing any change
- Use `-o 'addopts='` to clear any baked-in pytest flags

### Commit Conventions

```
type: concise subject line

Optional body.
```

Types: `fix:`, `feat:`, `refactor:`, `docs:`, `chore:`

### Key Rules

- **Never break prompt caching** — don't change context, tools, or system prompt mid-conversation
- **Message role alternation** — never two assistant or two user messages in a row
- Use `get_hermes_home()` from `hermes_constants` for all paths (profile-safe)
- Config values go in `config.yaml`, secrets go in `.env`
- New tools need a `check_fn` so they only appear when requirements are met
