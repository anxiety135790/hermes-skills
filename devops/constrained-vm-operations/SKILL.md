---
name: constrained-vm-operations
description: Operations for diagnosing and recovering resource-constrained Linux VMs — disk space auditing, memory optimization, service right-sizing.
---

# Constrained VM Operations

Operations guide for recovering from resource constraints on Linux VMs (e.g., GCP e2-micro with 1GB RAM, 28GB root partition). Covers disk space auditing, memory optimization, and service right-sizing.

## When to Use

- `df -h` shows >80% disk usage
- `du` or `find` times out on large filesystems
- User says "out of memory" / "saving resources" / "VM too slow"
- VM is in a resource death spiral
- After setting up Hermes and realizing memory is tight

## Quick Triage

```bash
# Overall resource picture
echo "=== Disk ===" && df -h / && echo "=== Memory ===" && free -h && echo "=== Top CPU/RAM consumers ===" && ps aux --sort=-%mem | head -8
```

If **disk** is the problem → See reference: [Disk Space Audit](references/disk-space-audit.md)
If **memory** is the problem → See reference: [Hermes Resource Optimization](references/hermes-resource-optimization.md)
If **both** are problems → Start with disk (frees indirect memory via cache/log cleanup), then optimize services.

## Sub-sections

### 1. Disk Space Audit

Detailed iterative procedure for auditing disk usage when `du` and `find` time out on large filesystems. See `references/disk-space-audit.md` for full coverage including:

- Tiered iterative analysis (known-heavy spots → drill into timing-out dirs → find large files)
- Common large directories on VM-like systems (snap, journald, uv cache, git)
- Stale temp file detection
- Safe cleanup candidates
- Pitfalls (sudo du, du -sh /* timeouts, snap read-only filesystems)

### 2. Hermes Resource Optimization

Right-sizing Hermes services on low-memory VMs. See `references/hermes-resource-optimization.md` for full coverage including:

- Service priority table (Gateway must-keep vs WebUI/Caddy optional)
- Step-by-step procedure: stop WebUI, stop Caddy, remove watchdogs, clean up cpulimit
- Expected memory savings (80–120MB typical)
- Verification checklist
- Pitfalls (don't stop Gateway, pkill scope safety, systemctl hang, disable vs stop semantics)

## Verification

After cleanup, confirm:

```bash
# Disk
df -h / && echo "---" && free -h
# No critical services stopped
ss -tlnp | grep -E '(gateway|hermes)' || echo "Gateway check manually"
```
