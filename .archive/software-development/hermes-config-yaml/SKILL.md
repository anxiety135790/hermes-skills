---
name: hermes-config-yaml
description: Hermes config.yaml 正确编辑方法 — 避免 hermes config set 对嵌套结构（custom_providers）的破坏性输出，改用 patch 工具直接编辑 YAML。
triggers:
  - hermes config set 失效
  - custom_providers 格式错误
  - hermes config bug yaml
  - hermes config set 产生畸形 YAML
---

# Hermes Config YAML 正确编辑方法

## 核心问题

`hermes config set` 对嵌套结构（特别是 `custom_providers`）会产生畸形 YAML：

```yaml
# 错误输出示例
custom_providers[1]:
  - name: Chinese_model_x0.4...
custom_providers[2]:
  - name: deepseek_x0.4...
```

Hermes 会报 `Unknown provider 'custom:xxx'`，配置完全失效。

## 正确做法：用 patch 工具编辑

用 `patch` 工具直接修改 `~/.hermes/config.yaml`，保持标准 YAML 列表格式：

```yaml
# 正确格式
custom_providers:
  - name: Chinese_model_x0.4
    base_url: https://ai.centos.hk/v1
    api_key: ${CENTOS_HK_V1_API_KEY}
    model: MiniMax-M2.7
  - name: deepseek_x0.4
    base_url: https://ai.centos.hk/v1
    api_key: ${CENTOS_HK_ANTHROPIC_API_KEY}
    model: deepseek-v4-pro
    anthropic: true
```

## 适用场景

| 操作 | 推荐方式 |
|------|---------|
| 简单布尔/字符串值 | `hermes config set` ✅ |
| `custom_providers` 列表 | `patch` 工具 ❌ `hermes config set` |
| 嵌套 provider 配置 | `patch` 工具 |
| 多行复杂 YAML | `patch` 工具 |

## 标准 YAML 列表格式参考

```yaml
# 列表格式（正确）
custom_providers:
  - name: xxx
    model: yyy
  - name: zzz
    model: www

# NOT array index syntax（错误）
custom_providers[0]:
  ...
custom_providers[1]:
  ...
```

## 配置修改后验证

```bash
# 检查配置语法
hermes doctor

# 重启 gateway 使配置生效
hermes gateway restart
```

## 陷阱

- `hermes model` 命令需要交互式终端，无法在子进程中运行
- `hermes config set` 会静默产生畸形 YAML，不报错
- patch 后确认 YAML 缩进正确（空格，不能用 tab）
