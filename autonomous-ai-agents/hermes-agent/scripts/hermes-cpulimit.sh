#!/bin/bash
# hermes-cpulimit.sh — Persistent CPU limiter for Hermes Agent & WebUI
# Limits: Agent=80%, WebUI=50% (on a 2-core system)
#
# ⚠️ FIXED: Track cpulimit PIDs to avoid accumulation death spiral.
#   Old approach: cpulimit -p <PID> -l <limit> -b started a NEW process
#   every 10 seconds without killing old ones → hundreds of cpulimit
#   processes → crash → apport → CPU 100% death spiral.
#   New approach: kill stale cpulimit PIDs before spawning new ones.

AGENT_LIMIT=80
WEBUI_LIMIT=50
POLL_INTERVAL=10  # seconds between checks
HERMES_HOME="${HOME}/.hermes"
CPULIMIT_PID_FILE="${HERMES_HOME}/.cpulimit_pids.$$"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

# Kill any cpulimit processes that were spawned by a PREVIOUS run of this script
# (but not the current run — those are tracked in CPULIMIT_PID_FILE)
cleanup_stale_cpulimit() {
    local exclude_pids=""
    if [ -f "$CPULIMIT_PID_FILE" ]; then
        exclude_pids=$(cat "$CPULIMIT_PID_FILE" 2>/dev/null)
        rm -f "$CPULIMIT_PID_FILE"
    fi

    # Kill all cpulimit processes NOT spawned by our current session
    for pid in $(pgrep -x cpulimit 2>/dev/null); do
        local skip=false
        if [ -n "$exclude_pids" ]; then
            for ep in $exclude_pids; do
                [ "$pid" = "$ep" ] && skip=true && break
            done
        fi
        $skip && continue
        kill "$pid" 2>/dev/null || true
        log "Killed stale cpulimit PID $pid"
    done
}

apply_limits() {
    local agent_pid webui_pid new_agent_cpulimit new_webui_cpulimit

    # Clean up stale cpulimit processes from previous cycles
    cleanup_stale_cpulimit

    # Find Hermes Agent (gateway)
    agent_pid=$(pgrep -f "hermes_cli.*gateway.*run" | head -1)
    # Find Hermes WebUI server
    webui_pid=$(pgrep -f "hermes-webui/server.py" | head -1)

    if [ -n "$agent_pid" ]; then
        cpulimit -p "$agent_pid" -l $AGENT_LIMIT -b -m -q 2>/dev/null
        new_cpulimit_pid=$!
        echo "$new_cpulimit_pid" >> "$CPULIMIT_PID_FILE"
        log "Agent (PID $agent_pid) → ${AGENT_LIMIT}% (cpulimit PID $new_cpulimit_pid)"
    fi

    if [ -n "$webui_pid" ]; then
        cpulimit -p "$webui_pid" -l $WEBUI_LIMIT -b -m -q 2>/dev/null
        new_cpulimit_pid=$!
        echo "$new_cpulimit_pid" >> "$CPULIMIT_PID_FILE"
        log "WebUI (PID $webui_pid) → ${WEBUI_LIMIT}% (cpulimit PID $new_cpulimit_pid)"
    fi
}

# Initial pass — wait a moment for processes to be up
sleep 5
apply_limits

# Continuous monitoring loop
while true; do
    sleep $POLL_INTERVAL
    apply_limits
done
