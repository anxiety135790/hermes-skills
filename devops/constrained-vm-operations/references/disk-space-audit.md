# Disk Space Audit

Audit disk usage on Linux systems, especially when `du` and `find` time out on large filesystems. Common in small-root-partition VMs (28G) where `/home`, `/snap`, `/var` each exceed tool timeout limits.

## Quick Assessment

```bash
df -h /
```

If >80% full, proceed to iterative analysis.

## When `du` Times Out

On systems with large filesystems, `du -sh /*`, `du -sh /home`, etc. regularly time out (60-180s). Do NOT keep retrying with longer timeouts.

**Correct approach:** Use `execute_code` with Python + `subprocess.run()` with per-directory short timeouts, iterating over subdirectories.

### Tier 1: Check known-heavy spots (direct)

```python
import subprocess, os

targets = [
    '/snap',
    '/var/log',
    '/var/lib/snapd',
    '/var/lib/apt',
    '/var/cache',
    '/home/<user>/.cache',
    '/home/<user>/.hermes',
]
for d in targets:
    if os.path.exists(d):
        r = subprocess.run(['du', '-sh', d], capture_output=True, text=True, timeout=15)
        print(r.stdout.strip())
```

### Tier 2: Drill into timeouting directories

When a parent dir times out, list its children and check each individually:

```python
for item in os.listdir('/path/to/big-dir'):
    itemp = os.path.join('/path/to/big-dir', item)
    if os.path.isdir(itemp) and not item.startswith('.'):
        r = subprocess.run(['du', '-sh', itemp], capture_output=True, text=True, timeout=10)
        print(r.stdout.strip())
```

### Tier 3: Find large files (>50MB)

When `find / -size +50M` times out, scope it:

```python
# Limit to one filesystem
subprocess.run(['find', '/home', '-xdev', '-type', 'f', '-size', '+50M'],
               capture_output=True, text=True, timeout=30)
```

## Common Large Directories on VM-Like Systems

| Location | Typical Size | Notes |
|----------|-------------|-------|
| `/snap` | 2-4G | Snap packages; google-cloud-cli alone is ~2.9G |
| `/var/lib/snapd` | ~1.6G | Snap package data |
| `/var/log/journal` | ~1.1G | systemd journal; vacuum with `journalctl` |
| `/var/log/syslog*` | 15-50M | Rotated syslog |
| `~/.cache/uv` | 1-2G | uv package cache + stale `.tmp*` files (PyTorch/nvidia download leftovers) |
| `~/.cache/ms-playwright` | ~630M | Playwright browser binaries |
| `~/.hermes/<repo>/.git` | 150-300M | Git history |

## Stale Temp File Detection

Look for `.tmp*` directories in cache locations. Check age:

```python
import os, datetime
for f in ['~/.cache/uv/.tmp2PjGLl', '~/.cache/uv/.tmp9bCTyy']:
    stat_info = os.stat(os.path.expanduser(f))
    print(f"{f}: {datetime.datetime.fromtimestamp(stat_info.st_mtime)}")
```

If >24h old and not in active use, safe to delete.

## Cleanup Candidates (safe removals)

```bash
# Stale uv temp files (check age first)
rm -rf ~/.cache/uv/.tmp*

# Journal log vacuum (keeps last 200M)
sudo journalctl --vacuum-size=200M

# Vacuum all journal logs
sudo journalctl --vacuum-time=7d

# Compress git history
cd ~/.hermes/hermes-agent && git gc --aggressive

# Remove old rotated syslogs (keep current only)
sudo rm /var/log/syslog.1 /var/log/auth.log.1

# Clean apt cache
sudo apt clean

# Cache old pip packages
pip cache purge
# or: uv cache clean
```

## Pitfalls

- `du -sh /*` or `find / -size +50M` will time out if `/home`, `/snap`, or `/var` is large (1G+). Always scope iteratively.
- `sudo du` requires approval; use non-sudo or limit to user-accessible dirs first.
- Python `os.path.getsize()` on directories returns not useful; use `du` or `shutil.disk_usage()`.
- Snap packages are read-only; you can remove snaps with `snap remove <name>` but cannot selectively delete files inside them.
- `.git` directories in Hermes repos can reach 250M+; `git gc --aggressive` shrinks them but is slow.
