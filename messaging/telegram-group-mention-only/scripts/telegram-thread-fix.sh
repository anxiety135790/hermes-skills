#!/bin/bash
# Verify and fix Telegram "Thread N not found" warnings
# Usage: bash scripts/telegram-thread-fix.sh [thread_id]

set -e

THREAD_ID="${1:-}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
LOG_FILE="$HERMES_HOME/logs/gateway.log"
CONFIG_FILE="$HERMES_HOME/config.yaml"
SESSION_DIR="$HERMES_HOME/sessions"

echo "=== Telegram Thread Fix ==="

# 1. Check config: dm_topics must be under platforms.telegram.extra, not top-level telegram.extra
echo ""
echo "[1] Checking dm_topics config path..."
if grep -q "^platforms:" "$CONFIG_FILE"; then
    echo "    platforms: section exists — checking dm_topics path..."
    python3 -c "
import yaml, sys
with open('$CONFIG_FILE') as f:
    cfg = yaml.safe_load(f)
platforms = cfg.get('platforms', {})
telegram_extra = platforms.get('telegram', {}).get('extra', {})
dm_topics = telegram_extra.get('dm_topics', 'NOT SET')
print(f'    dm_topics value: {dm_topics}')
if dm_topics == 'NOT SET':
    print('    STATUS: NOT configured — OK if you dont need DM topics')
elif dm_topics == []:
    print('    STATUS: Empty list — auto-creation disabled, GOOD')
else:
    print(f'    STATUS: Configured with {len(dm_topics)} entries — may cause Thread warnings if bot lacks permissions')
"
else
    echo "    WARNING: No platforms: section found — dm_topics may be in wrong location"
    echo "    Add under: platforms: { telegram: { extra: { dm_topics: [] } } }"
fi

# 2. Find sessions with the given thread ID (or any known stuck thread IDs)
echo ""
echo "[2] Checking for stuck sessions..."
if [ -n "$THREAD_ID" ]; then
    STUCK_IDS="$THREAD_ID"
else
    # Auto-detect from latest gateway log
    STUCK_IDS=$(grep -oP 'Thread \K\d+' "$LOG_FILE" 2>/dev/null | sort -u | head -5 || echo "")
fi

if [ -z "$STUCK_IDS" ]; then
    echo "    No stuck thread IDs found in logs"
else
    for tid in $STUCK_IDS; do
        echo "    Searching for sessions with thread ID: $tid"
        MATCHED=$(grep -l "$tid" "$SESSION_DIR"/session_*.json 2>/dev/null || true)
        if [ -n "$MATCHED" ]; then
            echo "    FOUND stuck sessions:"
            echo "$MATCHED" | while read f; do
                echo "      - $(basename "$f")"
            done
        else
            echo "    No stuck sessions found for $tid"
        fi
    done
fi

# 3. Check latest gateway log for warnings
echo ""
echo "[3] Recent Thread warnings in gateway.log..."
grep -c "Thread.*not found" "$LOG_FILE" >/dev/null 2>&1 && {
    echo "    Total Thread warnings: $(grep -c "Thread.*not found" "$LOG_FILE")"
    grep "Thread.*not found" "$LOG_FILE" | tail -3 | sed 's/^/    /'
} || echo "    No Thread warnings found"

# 4. Summary / recommended action
echo ""
echo "[4] Recommended fix (if warnings persist):"
echo "    # Delete stuck sessions:"
if [ -n "$STUCK_IDS" ]; then
    for tid in $STUCK_IDS; do
        MATCHED=$(grep -l "$tid" "$SESSION_DIR"/session_*.json 2>/dev/null || true)
        [ -n "$MATCHED" ] && echo "    rm $MATCHED"
    done
fi
echo "    # Restart gateway:"
echo "    systemctl --user restart hermes-gateway"
echo "    # Then: sleep 8 && tail -15 ~/.hermes/logs/gateway.log"
