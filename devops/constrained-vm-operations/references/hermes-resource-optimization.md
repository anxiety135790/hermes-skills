# Hermes Resource Optimization

Guide for reducing resource usage on a Hermes Agent deployment when running on constrained VMs (e.g. GCP e2-micro with 1GB RAM).

## When to Use

- User says "saving resources" / "out of memory" / "VM too slow"
- User asks which services are necessary vs optional
- After setting up Hermes and realizing memory is tight
- User stops using WebUI and wants to reclaim the memory

## Service Priority

| Service | Typical RAM | Essential? | Notes |
|---------|-------------|-----------|-------|
| **Gateway** | 180–250MB (15–25%) | ✅ **Must keep** | Handles Telegram/Discord/etc. communication |
| **WebUI** | 60–80MB (5–8%) | ❌ Optional | Web dashboard. Useless if user interacts via Telegram only |
| **Caddy** | 10–20MB (1–2%) | ❌ Optional | Reverse proxy for WebUI. Only needed if WebUI is used externally |
| **cpulimit** | Variable | ❌ Optional | Can cause death spiral (see hermes-agent skill) |
| **Watchdog scripts** | Minimal | ❌ Optional | Only needed if services auto-die frequently |

## Procedure

### 1. Check current resource state

```bash
# Memory overview
free -h

# Top memory consumers
ps aux --sort=-%mem | head -10

# Check which services are listening
ss -tlnp | grep -E '(8787|2080|8000)'

# Check for cron watchdogs
crontab -l 2>/dev/null | grep -v '^#'
```

### 2. Stop WebUI (if running)

```bash
# Find PID
ps aux | grep server\\.py | grep -v grep

# Kill by PID (preferred - more precise)
kill <PID>

# Or by process name
pkill -f "server\\.py"
```

Verify:
```bash
ss -tlnp | grep 8787 || echo "WebUI port freed"
```

### 3. Stop Caddy (if running)

```bash
# System Caddy (systemd)
sudo systemctl stop caddy
sudo systemctl disable caddy   # prevent auto-start on reboot
```

Verify:
```bash
ss -tlnp | grep 2080 || echo "Caddy port freed"
```

### 4. Clean up watchdogs and cron jobs

```bash
# Check for watchdog scripts
ls ~/.hermes/scripts/webui-watchdog* 2>/dev/null

# Remove cron-based watchdog
(crontab -l 2>/dev/null | grep -v webui-watchdog) | crontab -

# Remove Hermes cron watchdog if exists
# Use cronjob tool: action='list' then action='remove' for each watchdog job
```

### 5. Clean up cpulimit death spiral (if present)

```bash
sudo systemctl stop hermes-cpulimit.service 2>/dev/null
sudo systemctl disable hermes-cpulimit.service 2>/dev/null
sudo killall -9 cpulimit apport 2>/dev/null
```

### 6. Final verification

```bash
echo "=== Memory ===" && free -h
echo "=== Remaining services ===" && ps aux --sort=-%mem | grep -E '(gateway|server\\.py|caddy)' | grep -v grep
echo "=== Listening ports ===" && ss -tlnp | grep -E '(8787|2080|8000)' || echo "All optional ports freed"
```

## Expected Savings

- **WebUI + Caddy only**: ~80–100MB freed
- **WebUI + Caddy + cpulimit**: ~100–120MB freed
- **Typical result**: available memory improves from ~70MB to ~300MB+ on a 1GB VM

## Verification Checklist

- [ ] Gateway still running (user can still message via Telegram)
- [ ] WebUI port 8787 freed
- [ ] Caddy port 2080 freed
- [ ] Caddy auto-start disabled
- [ ] Watchdogs removed from cron
- [ ] cpulimit stopped and disabled (if applicable)

## Pitfalls

- **Don't stop the Gateway**: The gateway process (running `-m hermes_cli.main gateway run`) is essential. Stopping it means the user can no longer communicate with the agent via Telegram/Discord/etc.
- **pkill -f can match too broadly**: `pkill -f "server\\.py"` is safe because the regex pattern is unique. But for general cases, use explicit PIDs from `ps aux` instead.
- **systemctl stop may hang**: If systemd is slow or the service is in a bad state, `systemctl stop` can time out. Use `kill <PID>` as fallback.
- **WebUI will NOT restart automatically**: After killing WebUI and removing watchdogs, it stays dead. If the user later wants it back, they need to start it explicitly. Don't leave stale watchdog jobs that would restart it.
- **Port freed but process still alive**: Always verify with **both** `ss -tlnp | grep PORT` AND `ps aux | grep process`. Sometimes a process dies but port lingers in TIME_WAIT — harmless but can confuse verification. Use `fuser PORT/tcp` for definitive check.
- **Disable auto-start for non-essential services**: After stopping, also `systemctl disable` so restarting the VM doesn't bring them back. However, only do this if the user explicitly wants persistent resource savings. If they might want WebUI after a reboot, just stop it without disabling.
