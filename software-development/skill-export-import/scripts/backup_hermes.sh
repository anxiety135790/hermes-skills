#!/bin/bash
set -e

BACKUP_ROOT="/home/milvillena99/Obsidian/Ideaverse Pro 2.5/YOLO/skills/hermes/backups"
SOURCE_DIR="/home/milvillena99/.hermes"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_ROOT/backup_$TIMESTAMP"
KEEP_DAYS=7

mkdir -p "$BACKUP_PATH"

# 全量备份
cp -av "$SOURCE_DIR/config.yaml" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/.env" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/auth.json" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/SOUL.md" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/google_token.json" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/google_client_secret.json" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/channel_directory.json" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/gateway_state.json" "$BACKUP_PATH/"

cp -av "$SOURCE_DIR/skills" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/sessions" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/memories" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/cron" "$BACKUP_PATH/"
cp -av "$SOURCE_DIR/kanban.db" "$BACKUP_PATH/"

# 保留最近7天
find "$BACKUP_ROOT" -maxdepth 1 -type d -name "backup_*" | sort -r | tail -n +$((KEEP_DAYS + 1)) | xargs -r rm -rf

echo "Backup complete: $BACKUP_PATH"
