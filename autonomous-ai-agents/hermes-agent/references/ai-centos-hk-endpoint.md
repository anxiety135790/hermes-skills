# ai.centos.hk — Custom Endpoint Reference

## Endpoint
- **Base URL:** `https://ai.centos.hk/v1`
- **Auth:** Bearer token (API key)

## Available Models (2025-05-08)

| Model | Anthropic Endpoint | Status |
|-------|---------------------|--------|
| `deepseek-v4-flash` | ✅ supported | Working |
| `deepseek-v4-pro` | ✅ supported | Working |

## Unavailable Models (tested, not found)
- `MiniMax-M2.7` ❌ — `model_not_found`,分组下无可用渠道
- `minimax-01` ❌ — same error

## Hermes Configuration (Multiple Providers)

```yaml
model:
  default: MiniMax-M2.7
  provider: custom:deepseek_x0.4
  base_url: https://ai.centos.hk/v1
  api_key: <key>

custom_providers:
  - name: Chinese_model_x0.4
    base_url: https://ai.centos.hk/v1
    api_key: sk-HzG...NVUS
    model: MiniMax-M2.7
  - name: deepseek_x0.4
    base_url: https://ai.centos.hk/v1
    api_key: sk-HSn...TmBI
    model: deepseek-v4-pro
    anthropic: true
```

Switch model mid-session: `/model deepseek_x0.4`

### ⚠️ `hermes config set` gotcha for `custom_providers`

Setting it as a JSON array produces畸形 YAML (`custom_providers[1]:` / `custom_providers[2]:`). **Always edit the YAML file directly** rather than using `hermes config set` for this field.

## To Clear
```bash
hermes config set model.default ""
hermes config set model.provider ""
hermes config set model.base_url ""
hermes config set model.api_key ""
```

## Probe Commands

```bash
# List models
curl -s -H "Authorization: Bearer <key>" https://ai.centos.hk/v1/models

# Test a model (Anthropic format)
curl -s -X POST https://ai.centos.hk/v1/messages \
  -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"<model-id>","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}'
```
