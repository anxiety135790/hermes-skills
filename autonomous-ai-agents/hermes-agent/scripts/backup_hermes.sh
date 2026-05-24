#!/bin/bash
# Hermes 全量备份脚本（profile 感知版）
# 备份根目录核心文件 + 根目录数据 + 所有 profile 独立数据
# 保留最近 7 天，旧备份自动清理
set -e

HERMES_HOME="/home/milvillena99/.hermes"
BACKUP_ROOT="$HERMES_HOME/bk"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_ROOT/backup_$TIMESTAMP"
KEEP_DAYS=7

mkdir -p "$BACKUP_PATH"

echo "📦 Hermes 全量备份 — $TIMESTAMP"
echo "──────────────────────────────"

# 1. 根目录核心文件（最快）
echo "【1/4】根目录核心文件..."
for f in config.yaml .env auth.json SOUL.md google_token.json \
         google_client_secret.json channel_directory.json \
         gateway_state.json kanban.db; do
    [ -f "$HERMES_HOME/$f" ] && cp -a "$HERMES_HOME/$f" "$BACKUP_PATH/" || true
done
echo "   ✓ 核心文件备份完成"

# 2. Profile 目录（各用户独立数据，量少）
echo "【2/4】Profile 目录..."
PROFILES_DIR="$HERMES_HOME/profiles"
if [ -d "$PROFILES_DIR" ]; then
    for profile in "$PROFILES_DIR"/*/; do
        name=$(basename "$profile")
        [ "$name" = "bk" ] && continue
        echo "   → $name"
        dest="$BACKUP_PATH/profiles/$name"
        mkdir -p "$dest"
        for item in config.yaml SOUL.md cron memories sessions plans workspace; do
            [ -e "$profile/$item" ] && cp -a "$profile/$item" "$dest/" 2>/dev/null || true
        done
    done
    echo "   ✓ Profile 备份完成"
else
    echo "   ℹ️ 无独立 profile"
fi

# 3. 根目录数据目录（skills 除外，放最后）
echo "【3/4】根目录数据目录..."
for dir in sessions memories cron; do
    if [ -d "$HERMES_HOME/$dir" ]; then
        cp -a "$HERMES_HOME/$dir" "$BACKUP_PATH/" 2>/dev/null || true
        echo "   ✓ $dir"
    fi
done

# 4. Skills（最大最慢，放最后）
echo "【4/4】Skills 目录..."
if [ -d "$HERMES_HOME/skills" ]; then
    cp -a "$HERMES_HOME/skills" "$BACKUP_PATH/" 2>/dev/null || true
    echo "   ✓ skills 备份完成 ($(du -sh "$HERMES_HOME/skills" | cut -f1))"
fi

# 5. 清理超过 KEEP_DAYS 天的旧备份
echo "──────────────────────────────"
echo "🧹 清理 ${KEEP_DAYS} 天前的旧备份..."
find "$BACKUP_ROOT" -maxdepth 1 -type d -name "backup_*" | sort -r | tail -n +$((KEEP_DAYS + 1)) | xargs -r rm -rf

echo "──────────────────────────────"
BACKUP_SIZE=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
echo "📊 备份大小: $BACKUP_SIZE"
echo "📁 $BACKUP_PATH"
echo "✅ 备份完成！"
