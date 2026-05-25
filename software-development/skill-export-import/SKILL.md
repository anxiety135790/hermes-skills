---
name: skill-export-import
description: 导出和导入 Hermes Agent 技能库和配置数据
triggers:
  - 导出技能
  - 导入技能
  - backup skills
  - restore skills
  - 备份导入hermes
---

# Skill Export/Import 导出导入技能

> **Directory name note:** The backup directory is `~/.hermes/input/` (singular), NOT `inputs` (plural). If the user says `inputs`, mentally correct to `input` before operating.

## Directory Structure

| 路径 | 作用 |
|------|------|
| `~/.hermes/skills/` | 当前激活的技能库 |
| `~/.hermes/input/` | 备份数据目录 |
| `~/.hermes/hermes-agent/skills/` | 内置技能（只读） |

## 导出技能

### 导出所有技能到 input
```bash
cp -r ~/.hermes/skills/* ~/.hermes/input/skills/
```

### 导出特定分类
```bash
cp -r ~/.hermes/skills/messaging ~/.hermes/input/skills/
```

### 导出单个技能
```bash
cp -r ~/.hermes/skills/messaging/telegram-group-mention-only ~/.hermes/input/skills/messaging/
```

## 导入技能

### 从 input 导入所有
```bash
cp -r ~/.hermes/input/skills/* ~/.hermes/skills/
```

### 从 input 导入特定分类
```bash
cp -r ~/.hermes/input/skills/messaging ~/.hermes/skills/
cp -r ~/.hermes/input/skills/security ~/.hermes/skills/
```

### 从 input 导入单个技能
```bash
mkdir -p ~/.hermes/skills/messaging
cp -r ~/.hermes/input/skills/messaging/telegram-group-mention-only ~/.hermes/skills/messaging/
```

## 比较差异

### 查看分类差异
```bash
diff <(ls -1 ~/.hermes/skills/ | sort) <(ls -1 ~/.hermes/input/skills/ | sort)
```

### 查看 input 中独有/缺失的分类
```bash
# input 中有但当前缺失的
comm -13 <(ls -1 ~/.hermes/skills/ | sort) <(ls -1 ~/.hermes/input/skills/ | sort)
```

### 查看某分类下的技能差异
```bash
diff <(ls -1 ~/.hermes/skills/messaging/) <(ls -1 ~/.hermes/input/skills/messaging/)
```

## 从任意备份目录恢复

备份不一定在 `~/.hermes/input/`，用户可能把备份放在 `~/bk/` 或任意路径。

### 1. 内容级差异对比

先用 MD5 精确对比哪些文件真正不同，不是简单比较文件名：

```python
import os, hashlib, json

def hash_file(path):
    if not os.path.exists(path): return None
    with open(path, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()

def load_index(base, subdir):
    d = os.path.join(base, subdir)
    files = {}
    for root, _, filenames in os.walk(d):
        for fn in filenames:
            fp = os.path.join(root, fn)
            rel = os.path.relpath(fp, d)
            files[rel] = {'size': os.path.getsize(fp), 'md5': hash_file(fp)}
    return files

bk = load_index('/home/user/bk', 'skills')
local = load_index(os.path.expanduser('~/.hermes'), 'skills')

only_bk = set(bk) - set(local)        # 备份独有 → 复制
only_local = set(local) - set(bk)     # 本地独有 → 保留
common = set(bk) & set(local)
diff = [k for k in common if bk[k]['md5'] != local[k]['md5']]  # 内容不同 → 决定覆盖方向
same = [k for k in common if bk[k]['md5'] == local[k]['md5']]  # 完全相同 → 跳过

print(f"备份独有: {len(only_bk)}, 本地独有: {len(only_local)}, 内容不同: {len(diff)}, 相同: {len(same)}")
```

### 2. sessions.json 合并（关键）

**不能直接覆盖！** 直接 `cp` 备份的 `sessions.json` 会丢失本地已有的 session 注册条目。

```python
with open('bk/sessions/sessions.json') as f:
    bk_reg = json.load(f)
with open(os.path.expanduser('~/.hermes/sessions/sessions.json')) as f:
    local_reg = json.load(f)

# 合并：备份条目打底，本地条目覆盖同名 key
merged = dict(bk_reg)
merged.update(local_reg)

# 先备份当前 sessions.json
import shutil
shutil.copy2(os.path.expanduser('~/.hermes/sessions/sessions.json'),
             os.path.expanduser('~/.hermes/sessions/sessions.json.bak'))

with open(os.path.expanduser('~/.hermes/sessions/sessions.json'), 'w') as f:
    json.dump(merged, f, indent=2, ensure_ascii=False)
```

### 3. 执行恢复

```bash
# 复制备份独有文件（skill 和 session）
cp -rn ~/bk/sessions/* ~/.hermes/sessions/   # -n 不覆盖已有
cp -rn ~/bk/skills/* ~/.hermes/skills/
```

> **注意**：`cp -r` 会覆盖同名文件。如果备份版本比本地旧（如 skill 版本回退），先用 diff 确认再决定覆盖方向。

**一次性 Python 合并脚本（推荐）：** 用 `shutil.copy2` + MD5 判断一次性完成全部合并，保留时间戳：

```python
# 技能：备份独有 → 复制；内容不同 → 覆盖；相同 → 跳过
for root, dirs, filenames in os.walk(bk_skills_dir):
    for fn in filenames:
        rel = os.path.relpath(os.path.join(root, fn), bk_skills_dir)
        dst = os.path.join(local_skills_dir, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst) or hash_file(src) != hash_file(dst):
            shutil.copy2(src, dst)  # copy2 保留 mtime
```

### 3.1 config.yaml 不参与合并

备份和本地的 `config.yaml` 通常连向不同 provider/模型，**不应自动合并**。对比报告里标注差异即可，由用户决定是否手动迁移。

### 3.2 skip 非数据文件

合并时跳过这些：
- `*.tmp`, `*.lock`, `*.log` — 临时/锁文件
- `*.pyc`, `__pycache__/` — 编译产物
- `.hub/`, `.usage`, `.bundled`, `.curator_state` — 运行时元数据
- `*.bak` — 之前的备份（避免嵌套）

## 导入记忆和会话

记忆数据 (`memories/`) 通常为空，记忆从会话历史中重建：

```bash
# 导入所有会话文件（不含 sessions.json，已单独合并）
for f in ~/.hermes/input/sessions/*; do
    [[ "$(basename "$f")" == "sessions.json" ]] && continue
    cp -n "$f" ~/.hermes/sessions/
done

# 验证
echo "Sessions:" && ls ~/.hermes/sessions/ | wc -l
```

## 导入缺失的技能

```bash
# 创建目标目录并复制
mkdir -p ~/.hermes/skills/messaging ~/.hermes/skills/security
cp -r ~/.hermes/input/skills/messaging/* ~/.hermes/skills/messaging/
cp -r ~/.hermes/input/skills/security/* ~/.hermes/skills/security/

# 验证
ls ~/.hermes/skills/messaging/
ls ~/.hermes/skills/security/
```

## 完整备份流程

### 1. 创建带时间戳的备份
```bash
BACKUP_DIR=~/.hermes/skills_backup_$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
cp -r ~/.hermes/skills/* $BACKUP_DIR/
echo "Backup: $BACKUP_DIR"
```

### 2. 导出到 input 目录
```bash
# 备份当前 input（如果存在）
[[ -d ~/.hermes/input/skills ]] && mv ~/.hermes/input ~/.hermes/input_bak_$(date +%Y%m%d_%H%M%S)

# 创建新的 input 结构
mkdir -p ~/.hermes/input/skills
cp -r ~/.hermes/skills/* ~/.hermes/input/skills/
```

### 3. 从备份恢复
```bash
# 恢复到 input
cp -r ~/.hermes/input/skills/* ~/.hermes/skills/
```

## 注意事项

- 内置技能在 `~/.hermes/hermes-agent/skills/` 是只读的，不要直接修改
- 自定义技能应放在 `~/.hermes/skills/` 下
- `input/` 目录通常作为数据迁移的中间目录
- 导入前建议先比较差异，避免覆盖新技能

## 验证导入结果
```bash
# 统计技能数量
echo "Current skills:" && ls ~/.hermes/skills/ | wc -l
echo "Input skills:" && ls ~/.hermes/input/skills/ | wc -l

# 验证特定技能存在
ls ~/.hermes/skills/messaging/telegram-group-mention-only
ls ~/.hermes/skills/security/command-access-control
```

### 每日定时备份到 GitHub（git 同步）

将 Hermes skills 目录设为 git 仓库并每日自动推送至 GitHub，实现异地备份。

### 先决条件
- GitHub Personal Access Token（Classic，需 `repo` 权限）
- git 已安装

### 设置步骤

1. **在 GitHub 上创建仓库**（通过 API 或手动）：
   ```bash
   curl -s -X POST \
     -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/user/repos \
     -d '{"name":"hermes-skills","description":"Hermes Agent skills backup","private":false}'
   ```

2. **初始化 skills 目录为 git 仓库**：
   ```bash
   cd ~/.hermes/skills
   git init
   git checkout -b main
   ```

3. **添加 `.gitignore`**（跳过临时文件）：
   ```text
   *~
   .DS_Store
   **/node_modules/**
   **/.DS_Store
   ```

4. **设置远程仓库并保存认证**：
   ```bash
   git remote add origin https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/hermes-skills.git
   git config credential.helper store
   echo "https://$GITHUB_USER:$GITHUB_TOKEN@github.com" > ~/.git-credentials
   chmod 600 ~/.git-credentials
   git add -A
   git commit -m "🎉 Initial commit: all Hermes skills"
   git push -u origin main
   ```

5. **创建同步脚本** `~/.hermes/scripts/sync-skills.sh`：
   ```bash
   #!/bin/bash
   set -e
   cd "$HOME/.hermes/skills"
   if git diff --quiet && git diff --cached --quiet; then
       echo "✅ 没有变更，跳过提交"
       exit 0
   fi
   TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
   git add -A
   git commit -m "🔄 Auto-sync skills ($TIMESTAMP)"
   git push origin main
   echo "✅ Skills 同步完成: $TIMESTAMP"
   ```
   然后 `chmod +x ~/.hermes/scripts/sync-skills.sh`

6. **设置每日 cronjob**（推荐凌晨 3:00）：
   ```bash
   # cronjob(action='create', prompt='', script='sync-skills.sh', schedule='0 3 * * *', no_agent=True)
   ```

### 陷阱
- **一次性提供所有信息**：用户可能无法一次性提供 GitHub 用户名、仓库名、token。应逐步索取：先问用户名 → 再问仓库方案（新建/已有） → 最后要 token。
- **Token 安全性**：`~/.git-credentials` 是明文存储，权限设为 `chmod 600`。首次推送后建议更新 remote URL 去除 token：`git remote set-url origin https://github.com/$USER/$REPO.git`，credential store 会接管后续认证。

---

### 每日定时备份到 Obsidian

### 备份目标
- **Obsidian Vault 路径**: `~/Obsidian/Ideaverse Pro 2.5/YOLO/skills/hermes/`
- **全量备份**: 每日 23:00 执行，保留 7 天
- **Skills 增量同步**: 每日 00:00 执行（无保留策略）

### 备份脚本
脚本放在 `~/.hermes/scripts/backup_hermes.sh`（文件名即 `cronjob` 工具的 script 参数）：

```bash
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
```

### cronjob 工具使用注意
- **script 参数**: 必须使用相对于 `~/.hermes/scripts/` 的文件名，不能用绝对路径或 `~` 开头
  - ✅ `backup_hermes.sh`
  - ❌ `/home/milvillena99/.hermes/scripts/backup_hermes.sh`
  - ❌ `~/.hermes/scripts/backup_hermes.sh`
  - ❌ `rm -rf ~/Obsidian/.../hermes && cp -av ~/.hermes/skills ~/Obsidian/.../hermes`
- 脚本需要 `chmod +x` 后才能被 cronjob 正常执行
- rsync 不可用时，用 `rm -rf` + `cp -av` 代替

### cronjob no_agent 模式常见失败

**症状**: cron job 一直报 `error` 状态，但手动执行脚本完全正常。

**检查点**: 查看 `~/.hermes/cron/output/<job_id>/<timestamp>.md` 中的错误信息。

**陷阱 1 — script 参数是命令而非路径**  
`no_agent=True` 时，`script` 字段必须是脚本**文件名**（在 `~/.hermes/scripts/` 下）。如果填入完整 shell 命令，系统会把整个字符串当作脚本路径去找，导致 `Script not found` 错误。

```python
# 错误配置
{"script": "rm -rf ~/Obsidian/.../hermes && cp -av ~/.hermes/skills ~/Obsidian/.../hermes", "no_agent": True}
# → Script not found: /home/milvillena99/.hermes/scripts/rm -rf ~/Obsidian/.../hermes && ...

# 正确配置
{"script": "backup_skills_to_obsidian.sh", "no_agent": True}
```

**陷阱 2 — cron 环境缺少 PATH**  
cron 执行时环境变量极少，`bash`/`cp` 等命令可能不在 PATH 中。使用绝对路径或显式 `source /etc/profile`。

### 其他参考
- `references/cloudflare-tunnel.md` — 使用 Cloudflare 临时隧道暴露本地 WebUI 到公网

