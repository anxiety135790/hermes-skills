# Self-Update Verification (Hermes Agent)

## The Problem

Running `hermes update` (or `/update` in gateway) triggers a gateway restart. The command times out in the terminal tool because the process is killed mid-execution by the restart. The calling terminal session sees exit code -1.

**This is expected behavior, not an error.** The timeout means the update is running, not that it failed.

## Reliable Self-Update Pattern

### Step 1: Record version before

```bash
cd ~/.hermes/hermes-agent && git log --oneline -1 && git rev-parse HEAD | cut -c1-8
```

### Step 2: Pull directly (bypasses gateway restart)

```bash
cd ~/.hermes/hermes-agent && git pull origin main 2>&1
```

Fast-forward pulls are safe. The gateway restart is NOT triggered by `git pull` — only by `hermes update` or `/update`.

### Step 3: Confirm version after

```bash
cd ~/.hermes/hermes-agent && git log --oneline -1 && git rev-parse HEAD | cut -c1-8
```

Compare the commit hash to confirm the pull succeeded.

### Step 4: Restart gateway to activate

Gateway must be restarted before the new code takes effect:

```bash
hermes gateway restart
```

Or trigger via Telegram: send any message and the restarted gateway will pick up the new code.

## Why Not Just `/update`?

- `/update` calls `hermes update` internally
- `hermes update` calls the bootstrap script which may trigger gateway restart
- The restart kills the calling process → timeout in terminal tool
- `git pull` sidesteps this entirely

## Remote Check (optional)

Before pulling, check if there are upstream changes:

```bash
cd ~/.hermes/hermes-agent && git fetch origin && git log HEAD..origin/main --oneline | head -5
```

Shows the last 5 commits you'd be pulling. If the list is very long (hundreds of commits), the codebase is far behind — still safe to pull, just a larger diff.

## What Counts as "Updated"

A fast-forward `git pull` moves HEAD to a new commit. The session's running process (before restart) is still the old version. Only a fresh process or gateway restart activates the new code.
