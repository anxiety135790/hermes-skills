# Production Resource Limits — Hermes Agent & WebUI

When running Hermes on low-resource VPS instances (1-2 vCPU, 1-2 GB RAM), LLM agent CPU usage can spike during inference or tool execution. Use `cpulimit` to prevent starvation.

## Architecture

```
┌─────────────────────────────────────────────┐
│  systemd: hermes-cpulimit.service          │
│  ┌───────────────────────────────────────┐ │
│  │ bash watcher script (polls every 10s) │ │
│  │ pgrep + cpulimit for each process     │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
┌───────────────┐       ┌───────────────────┐
│ Hermes Agent  │       │  Hermes WebUI     │
│ cpulimit -l 80│       │  cpulimit -l 50   │
│ -m (monitor   │       │  -m (monitor      │
│  forks)       │       │   forks)          │
└───────────────┘       └───────────────────┘
```

## Key Commands

| Action | Command |
|--------|---------|
| Find agent PID | `pgrep -f "hermes_cli.*gateway.*run"` |
| Find WebUI PID | `pgrep -f "hermes-webui/server.py"` |
| Limit agent | `sudo cpulimit -p <PID> -l 80 -b -m -q` |
| Limit WebUI | `sudo cpulimit -p <PID> -l 50 -b -m -q` |
| Check running limits | `ps aux \| grep cpulimit \| grep -v grep` |

## Systemd Service

The service file at `/etc/systemd/system/hermes-cpulimit.service` runs a polling watcher as root. The watcher script (`~/.hermes/scripts/hermes-cpulimit.sh`) does:

1. **Wait 5 seconds** for processes to start
2. **Find PIDs** via `pgrep -f` with unique command-line fragments
3. **Apply cpulimit** with `-b` (background), `-m` (monitor forks), `-q` (quiet)
4. **Poll every 10 seconds** to catch process restarts

## Pitfalls

- **`-e python` catches ALL python processes**, not just Hermes — always target by PID via `pgrep -f` + `-p`
- **Sudo password prompts** block `cpulimit` from starting — ensure passwordless sudo for the relevant commands, or run the service as `root`
- **cpulimit duplicates are harmless** — running it again on an already-limited PID silently succeeds; clean up with `pkill -f 'cpulimit -p <PID>'`
