---
name: api-key-env-migration
description: 将 Hermes config.yaml 中的明文 API key 迁移到 .env 环境变量，改用 ${ENV_VAR} 引用 — 提升安全性。
triggers:
  - API key 明文
  - config 安全
  - .env 变量引用
  - API key 迁移
---

# API Key 环境变量迁移

## 目标

将 `config.yaml` 中的明文 API key 迁移到 `~/.hermes/.env`，config 中改用 `${ENV_VAR}` 引用。

## 步骤

### 1. 读取当前 config.yaml 中的 key

```bash
grep -n "api_key" ~/.hermes/config.yaml
```

### 2. 写入 .env（追加）

```bash
# 格式：VARNAME=实际key，不要加引号
echo 'CENTOS_HK_V1_API_KEY=sk-xxx' >> ~/.hermes/.env
echo 'DEEPSEEK_API_KEY=sk-21e7b5da784a4bc393c02a0b9153d928' >> ~/.hermes/.env
```

### 3. 用 patch 修改 config.yaml

把：
```yaml
api_key: sk-xxx
```

改成：
```yaml
api_key: ${CENTOS_HK_V1_API_KEY}
```

### 4. 验证 .env 格式正确

```bash
# .env 中每行是 VARNAME=value，不能有引号或 export
CENTOS_HK_V1_API_KEY=sk-xxx
DEEPSEEK_API_KEY=sk-21e7b5da784a4bc393c02a0b9153d928
```

### 5. 备份

```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.backup-$(date +%Y%m%d-%H%M%S)
cp ~/.hermes/.env ~/.hermes/.env.backup-$(date +%Y%m%d-%H%M%S)
```

## 多 provider 的 key 分离

每个 provider 的 key 独立命名，方便轮换：

```env
CENTOS_HK_V1_API_KEY=sk-xxx           # Chinese_model_x0.4
CENTOS_HK_ANTHROPIC_API_KEY=sk-yyy     # deepseek_x0.4 (anthropic mode)
DEEPSEEK_API_KEY=sk-zzz               # DeepSeek 原生
```

## 验证生效

```bash
hermes doctor
hermes gateway restart
```

## 安全收益

- API key 不再出现在 `config.yaml`（可安全分享）
- key 集中管理在 `.env`（已在 .gitignore）
- 切换 key 只需改 `.env`，无需改动 config.yaml
