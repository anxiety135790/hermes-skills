#!/bin/bash
# Hermes 服务状态检查脚本 (bash 版)
# 检查: Gateway / WebUI / Caddy / Cron / Profiles / 磁盘
# 用于 gateway 重启后或手动排障时的快速状态确认

HERMES_HOME="$HOME/.hermes"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "🔄 Hermes 服务状态检查"
echo "📅 $DATE"
echo "────────────────────────────────────────"

# 1. Gateway
if [ -f "$HERMES_HOME/gateway.pid" ]; then
    GW_DATA=$(cat "$HERMES_HOME/gateway.pid" 2>/dev/null)
    GW_PID=$(echo "$GW_DATA" | grep -oP 'pid.: \K[0-9]+')
    if [ -n "$GW_PID" ] && kill -0 "$GW_PID" 2>/dev/null; then
        GW_ELAPSED=$(ps -o etime= -p "$GW_PID" 2>/dev/null | xargs)
        echo "  ✅ Gateway — PID $GW_PID, 运行了 $GW_ELAPSED"
    else
        echo "  ❌ Gateway — PID 文件存在但进程已死"
    fi
else
    echo "  ❌ Gateway — 无 PID 文件"
fi

# 2. WebUI (port 8787)
SS_OUT=$(ss -tlnp 2>/dev/null)
WEBUI_LINE=$(echo "$SS_OUT" | grep ":8787")
if [ -n "$WEBUI_LINE" ]; then
    WEBUI_PID=$(echo "$WEBUI_LINE" | grep -oP 'pid=\K[0-9]+')
    echo "  ✅ WebUI — 端口 8787 监听中 (PID $WEBUI_PID)"
else
    echo "  ❌ WebUI — 端口 8787 未监听"
fi

# 3. Caddy (port 2080)
CADDY_LINE=$(echo "$SS_OUT" | grep ":2080")
CADDY_SVC=$(systemctl is-active caddy 2>/dev/null)
if [ -n "$CADDY_LINE" ] && [ "$CADDY_SVC" = "active" ]; then
    echo "  ✅ Caddy — systemd 活跃, 端口 2080 监听中"
elif [ -n "$CADDY_LINE" ]; then
    echo "  ✅ Caddy — 端口 2080 监听中"
elif [ "$CADDY_SVC" = "active" ]; then
    echo "  ✅ Caddy — systemd 活跃"
else
    echo "  ❌ Caddy — 未运行"
fi

# 4. Cron jobs
if [ -f "$HERMES_HOME/cron/jobs.json" ]; then
    CRON_JOBS=$(cat "$HERMES_HOME/cron/jobs.json" 2>/dev/null | grep -o '"enabled":[^,}]*' | grep -c 'true')
    echo "  ✅ Cron — 任务活跃: $CRON_JOBS"
else
    echo "  ℹ️ Cron — 无已配置任务"
fi

# 5. Profiles
if [ -d "$HERMES_HOME/profiles" ]; then
    PROFILES=$(ls -1 "$HERMES_HOME/profiles/" 2>/dev/null | tr '\n' ' ')
    echo "  ✅ Profiles — $PROFILES"
else
    echo "  ℹ️ Profiles — 无独立 profile"
fi

# 6. Disk
DISK_USED=$(df -h "$HOME" 2>/dev/null | tail -1 | awk '{print $5}')
DISK_INFO=$(df -h "$HOME" 2>/dev/null | tail -1 | awk '{print $3" / "$2}')
echo "  💾 磁盘 — 已用 $DISK_USED ($DISK_INFO)"

echo "────────────────────────────────────────"
echo "✅ 检查完成"
