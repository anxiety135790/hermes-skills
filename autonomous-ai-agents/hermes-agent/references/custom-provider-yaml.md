# Custom Provider YAML — Two Formats & The Gotcha

Hermes supports two YAML structures for custom providers. They coexist in `config.yaml`.

## Format 1: Legacy `custom_providers` (list)

```yaml
custom_providers:
  - name: my_provider
    base_url: https://ai.centos.hk/v1
    api_key: ${CENTOS_HK_V1_API_KEY}
    model: deepseek-v4-pro
    anthropic: true
  - name: chinese_model
    base_url: https://ai.centos.hk/v1
    api_key: ${CENTOS_HK_V1_API_KEY}
    model: MiniMax-M2.7
```

Reference in `model.*` section:
```yaml
model:
  provider: custom:my_provider    # format: custom:<name in custom_providers>
```

## Format 2: v12+ `providers` (dict)

```yaml
providers:
  deepseek_x0.4:
    base_url: https://ai.centos.hk/v1
    api_key: ${CENTOS_HK_V1_API_KEY}
    model: deepseek-v4-pro
    anthropic: true
  chinese_model_x0.4:
    base_url: https://ai.centos.hk/v1
    api_key: ${CENTOS_HK_V1_API_KEY}
    model: MiniMax-M2.7
```

Reference in `model.*` section:
```yaml
model:
  provider: deepseek_x0.4    # key directly from providers dict
```

## ⚠️ The `hermes config set` Gotcha

**Never use `hermes config set custom_providers ...` with a JSON array.** It writes array-index syntax instead of a proper YAML list:

```yaml
# WRONG — what hermes config set produces:
custom_providers[1]:
  - name: Chinese_model_x0.4
    model: MiniMax-M2.7
custom_providers[2]:
  name: deepseek_x0.4
  model: deepseek-v4-pro
```

This crashes with `Unknown provider 'custom:deepseek_x0.4'`.

**Correct approach:** Use `hermes config edit` or `patch` the file directly as standard YAML.

## Valid Fields Per Entry

| Field | Required | Notes |
|-------|----------|-------|
| `name` | ✅ | Unique identifier (used in `provider: custom:<name>`) |
| `base_url` | ✅ | API endpoint base (e.g. `https://ai.centos.hk/v1`) |
| `api_key` | ✅ | Plaintext or `${ENV_VAR}` reference |
| `model` | ✅ | Default model ID for this provider |
| `context_length` | | Context window size |
| `rate_limit_delay` | | Seconds to wait between requests |
| `key_env` | | Name of env var to read key from (alternative to inline `api_key`) |
| `api_mode` | | `anthropic` or `openai` (affects chat completions format) |
| `anthropic` | | `true` for Anthropic-format (messages endpoint) |

CamelCase aliases (`apiKey`, `baseUrl`) are auto-normalized to snake_case on read.

## Probe Command (OpenAI-format endpoint)

```bash
curl -s -X POST https://ai.centos.hk/v1/chat/completions \
  -H "Authorization: Bearer ${CENTOS_HK_V1_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-v4-pro","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}'
```

## Probe Command (Anthropic-format endpoint)

```bash
curl -s -X POST https://ai.centos.hk/v1/messages \
  -H "Authorization: Bearer ${CENTOS_HK_V1_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"deepseek-v4-pro","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}'
```

## Switching Mid-Session

```
/model deepseek_x0.4
```

Or from terminal: `hermes model` (interactive, requires a real terminal — won't work in subprocess/pipe mode).

## Cleanup (clear model config)

```bash
hermes config set model.default ""
hermes config set model.provider ""
hermes config set model.base_url ""
hermes config set model.api_key ""
```
