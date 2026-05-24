# Secrets Management: API Key → .env Migration

Full procedure for moving plaintext API keys from `~/.hermes/config.yaml` into `~/.hermes/.env`, using `${ENV_VAR}` references.

## Read Current Keys

```bash
grep -n "api_key" ~/.hermes/config.yaml
```

## Write to .env

```bash
# Format: VARNAME=actualkey, no quotes, no export
echo 'CENTOS_HK_V1_API_KEY=sk-xxx' >> ~/.hermes/.env
echo 'DEEPSEEK_API_KEY=sk-21e7...' >> ~/.hermes/.env
```

## Replace in config.yaml with Patch

```yaml
# Before:
api_key: sk-xxx

# After:
api_key: ${CENTOS_HK_V1_API_KEY}
```

## Verify .env Format

```bash
# Each line must be VARNAME=value — no quotes, no export prefix
CENTOS_HK_V1_API_KEY=sk-xxx
DEEPSEEK_API_KEY=sk-21e7b5da784a4bc393c02a0b9153d928
```

## Multi-Provider Naming Convention

Each provider gets a uniquely named variable for independent rotation:

```env
CENTOS_HK_V1_API_KEY=sk-xxx           # Chinese_model_x0.4
CENTOS_HK_ANTHROPIC_API_KEY=sk-yyy     # deepseek_x0.4 (Anthropic mode)
DEEPSEEK_API_KEY=sk-zzz               # DeepSeek native
```

## Verification

```bash
hermes doctor
hermes gateway restart
```

## Security Benefits

- API keys no longer appear in `config.yaml` (safe to share as reference config)
- Keys centrally managed in `.env` (already in `.gitignore`)
- Key rotation: change `.env` only, no `config.yaml` changes needed
