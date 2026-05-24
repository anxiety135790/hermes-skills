# DeepSeek Provider — API Key & Models

## Add API Key

```bash
echo "DEEPSEEK_API_KEY=sk-your-key" >> ~/.hermes/.env
```

## Switch Model In-Session

```
/model deepseek-v4-flash
```
or
```
/model deepseek-v4-pro
```

## Verify Key + List Models

```python
import json, urllib.request

KEY = "sk-your-key"
req = urllib.request.Request(
    "https://api.deepseek.com/v1/models",
    headers={"Authorization": f"Bearer {KEY}"}
)
with urllib.request.urlopen(req, timeout=8) as r:
    data = json.loads(r.read())
for m in data["data"]:
    print(m["id"])
```

## Available Models (2025-05)

| Model ID | Notes |
|----------|-------|
| `deepseek-v4-flash` | Fast / lightweight |
| `deepseek-v4-pro` | Pro version |

Probe via: `curl -s --max-time 8 https://api.deepseek.com/v1/models -H "Authorization: Bearer $DEEPSEEK_API_KEY"`

## Notes

- DeepSeek is a built-in provider — no `config.yaml` needed, key goes in `.env`
- Model switching is per-session (new session resets to `model.default` in config)
- DeepSeek API may be restricted in certain regions; the `/v1/models` probe will timeout if blocked
