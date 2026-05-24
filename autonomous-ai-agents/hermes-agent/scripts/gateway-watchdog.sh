#!/bin/bash
# Gateway 重启检测 Watchdog
# 比较当前 gateway PID 与上次记录的 PID
# 如果不同（重启了），输出全量状态报告
# 如果相同，保持静默
# 配合 no_agent cron 使用：stdout 输出即发送给用户

HERMES_HOME="$HOME/.hermes"
STATE_FILE="$HERMES_HOME/.gateway_last_pid"

# 读取当前 gateway PID
if [ ! -f "$HERMES_HOME/gateway.pid" ]; then
    exit 0
fi

GW_DATA=$(cat "$HERMES_HOME/gateway.pid" 2>/dev/null)
CURRENT_PID=$(echo "$GW_DATA" | grep -oP 'pid.: \K[0-9]+')
[ -z "$CURRENT_PID" ] && exit 0
kill -0 "$CURRENT_PID" 2>/dev/null || exit 0

# 读取上次记录的 PID
LAST_PID=""
[ -f "$STATE_FILE" ] && LAST_PID=$(cat "$STATE_FILE")

# 如果相同，静默退出
[ "$CURRENT_PID" = "$LAST_PID" ] && exit 0

# PID 变化了 — gateway 重启了
echo "$CURRENT_PID" > "$STATE_FILE"

echo "🔄 Gateway 已重启！服务状态报告："
echo ""

CHECK_SCRIPT="$HERMES_HOME/scripts/check-hermes-status.sh"
if [ -f "$CHECK_SCRIPT" ]; then
    bash "$CHECK_SCRIPT"
else
    echo "❌ 检查脚本不存在: $CHECK_SCRIPT"
fi

echo ""
echo "📌 Gateway PID: $CURRENT_PID"
