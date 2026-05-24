#!/usr/bin/env python3
"""
同步 model/provider 配置到所有 Hermes 用户 profile。

用法:
  python3 ~/.hermes/scripts/sync-model-provider.py              # 默认用 tg_826307909 同步到其他
  python3 ~/.hermes/scripts/sync-model-provider.py tg_1596476147  # 用指定 source 同步

说明:
  只同步 model 和 custom_providers 部分，保留每个 profile 的其他独有配置。
"""
import sys
import os
from pathlib import Path

HERMES_HOME = Path.home() / ".hermes"
PROFILES_DIR = HERMES_HOME / "profiles"

# 要同步的顶级 key（只共享 provider/model 相关的）
SYNC_KEYS = ["model", "custom_providers", "fallback_providers", "providers", "credential_pool_strategies"]


def load_yaml(path: Path) -> dict:
    import yaml
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data if isinstance(data, dict) else {}


def dump_yaml(path: Path, data: dict) -> None:
    import yaml
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)


def main():
    if len(sys.argv) > 1:
        source_name = sys.argv[1]
    else:
        source_name = "tg_826307909"  # default primary user

    if not PROFILES_DIR.is_dir():
        print(f"ERROR: profiles directory not found: {PROFILES_DIR}")
        sys.exit(1)

    profiles = sorted(d.name for d in PROFILES_DIR.iterdir() if d.is_dir() and not d.name.startswith("."))
    if not profiles:
        print("ERROR: no profiles found")
        sys.exit(1)
    if source_name not in profiles:
        print(f"ERROR: source '{source_name}' not in {profiles}")
        sys.exit(1)

    source_cfg_path = PROFILES_DIR / source_name / "config.yaml"
    if not source_cfg_path.exists():
        print(f"ERROR: source config not found: {source_cfg_path}")
        sys.exit(1)

    source_cfg = load_yaml(source_cfg_path)
    source_keys = {k: source_cfg.get(k) for k in SYNC_KEYS if k in source_cfg}
    if "model" not in source_keys:
        print(f"ERROR: source profile '{source_name}' missing 'model' key")
        sys.exit(1)

    m = source_keys.get("model", {})
    print(f"Source: [{source_name}]  model={m.get('default','?')} provider={m.get('provider','?')}")

    for prof_name in profiles:
        if prof_name == source_name:
            continue
        target_path = PROFILES_DIR / prof_name / "config.yaml"
        if not target_path.exists():
            print(f"  SKIP [{prof_name}] (no config.yaml)")
            continue
        target_cfg = load_yaml(target_path)
        modified = False
        for key, value in source_keys.items():
            if target_cfg.get(key) != value:
                target_cfg[key] = value
                modified = True
        if modified:
            dump_yaml(target_path, target_cfg)
            print(f"  SYNCED [{prof_name}]")
        else:
            print(f"  OK    [{prof_name}]")

    print("Done.")


if __name__ == "__main__":
    main()
