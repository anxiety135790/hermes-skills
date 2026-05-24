# Config YAML Editing Pitfalls

## The `hermes config set` Bug with Nested Structures

`hermes config set` silently produces malformed YAML for nested config structures, particularly `custom_providers`:

```yaml
# BAD — what hermes config set produces:
custom_providers[1]:
  - name: Chinese_model_x0.4...
custom_providers[2]:
  - name: deepseek_x0.4...
```

Hermes rejects this with `Unknown provider 'custom:xxx'` — the config becomes completely inoperable.

## Correct Approach: Use `patch` Tool

Always use the `patch` tool (or manual YAML editing) for nested/list-valued config sections:

```yaml
# GOOD — standard YAML list format
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

## When to Use Which

| Operation | Recommended Method |
|-----------|-------------------|
| Simple boolean/string values | `hermes config set` ✅ |
| `custom_providers` list | `patch` tool ❌ avoid `hermes config set` |
| Nested provider config | `patch` tool |
| Multi-line complex YAML | `patch` tool |

## Standard YAML List Format Reference

```yaml
# Correct list format
custom_providers:
  - name: xxx
    model: yyy
  - name: zzz
    model: www

# INCORRECT array index syntax
custom_providers[0]:
  ...
```

## Post-Edit Validation

```bash
hermes doctor
hermes gateway restart
```

## Pitfalls

- `hermes model` commands require interactive terminal — cannot run in subprocess
- `hermes config set` silently produces malformed YAML with no error message
- After patching, verify indentation uses spaces (not tabs)
