#!/usr/bin/env python3
"""
Command access control hook for Hermes Agent.
Supports three tiers: ADMIN_USER_IDS (full), LIMITED_USER_IDS (workspace-restricted, model-switch-only).

Env vars available from Hermes:
  HERMES_COMMAND_TEXT  — raw command string
  HERMES_USER_ID       — Telegram/DM user ID
  HERMES_CWD / PWD    — current working directory
  HERMES_SESSION_ID    — current session ID
  HERMES_PLATFORM      — telegram, discord, etc.
"""
import os
import sys
import json
import re

# --- Configuration ---
ADMIN_USER_IDS = {"826307909"}  # full access

LIMITED_USER_IDS = {"1596476147"}  # model-switch-only + workspace-restricted

# Commands only admins can run
ADMIN_ONLY_COMMANDS = {
    "/config", "/personality", "/reasoning",
    "/voice", "/verbose", "/yolo", "/restart", "/update",
    "/sethome", "/approve", "/deny", "/tools", "/skills",
    "/reload-skills", "/reload-mcp", "/cron", "/curator",
    "/kanban", "/plugins", "/branch", "/fast", "/debug",
    "/terminal", "/bash", "/exec",
}

# Commands limited users CAN use
LIMITED_ALLOWED_COMMANDS = {
    "/model", "/help", "/status", "/usage", "/history",
    "/save", "/copy", "/paste", "/image", "/clear",
    "/undo", "/title", "/compress", "/stop", "/queue",
    "/steer", "/goal", "/resume", "/new", "/reset",
    "/retry", "/copy", "/fast",
}

# Per-user workspace (jail directory)
USER_WORKSPACES = {
    "1596476147": "/home/milvillena99/hermes_workspace/1596476147",
}

# Per-user session directories (injected via HERMES_SESSION_DIR)
USER_SESSION_DIRS = {
    "1596476147": "/home/milvillena99/hermes_workspace/1596476147/sessions",
}
# --- End Configuration ---


def main():
    command_raw = os.getenv("HERMES_COMMAND_TEXT", "").strip()
    user_id = os.getenv("HERMES_USER_ID", "")
    cwd = os.getenv("HERMES_CWD", os.getenv("PWD", ""))
    session_id = os.getenv("HERMES_SESSION_ID", "")

    # Inject per-user session dir
    if user_id in USER_SESSION_DIRS:
        session_dir = USER_SESSION_DIRS[user_id]
        os.environ["HERMES_SESSION_DIR"] = session_dir
        os.makedirs(session_dir, exist_ok=True)

    if not command_raw:
        sys.exit(0)

    parts = command_raw.split()
    cmd = parts[0].lower()
    args = " ".join(parts[1:]) if len(parts) > 1 else ""

    # --- Workspace restriction for limited users ---
    if user_id in LIMITED_USER_IDS:
        allowed_dir = USER_WORKSPACES.get(user_id, "")

        # Block terminal/bash/exec entirely
        if cmd in {"/terminal", "/bash", "/exec"}:
            print(json.dumps({
                "status": "access_denied",
                "message": "🚫 Terminal commands are not allowed for your account"
            }), file=sys.stderr)
            sys.exit(1)

        # Block dangerous shell patterns regardless of cwd
        dangerous_patterns = ["rm -rf", "dd if=", "mkfs", ":(){ :|:& };:", "wget.*|curl.*http", "nc -e", "bash -i"]
        for pattern in dangerous_patterns:
            if re.search(pattern, command_raw):
                print(json.dumps({
                    "status": "access_denied",
                    "message": "🚫 Dangerous command pattern blocked"
                }), file=sys.stderr)
                sys.exit(1)

        # Block cd/rm/mv/cp outside workspace
        if allowed_dir:
            shell_indicators = [p for p in ["cd ", "rm ", "mv ", "cp ", "mkdir", "chmod", "chown"] if p in command_raw]
            if shell_indicators and not cwd.startswith(allowed_dir):
                print(json.dumps({
                    "status": "access_denied",
                    "message": f"🚫 You can only operate within {allowed_dir}"
                }), file=sys.stderr)
                sys.exit(1)

    # --- Admin: full access ---
    if user_id in ADMIN_USER_IDS:
        sys.exit(0)

    # --- Limited user: model switching only (no config) ---
    if user_id in LIMITED_USER_IDS:
        if cmd not in LIMITED_ALLOWED_COMMANDS:
            print(json.dumps({
                "status": "access_denied",
                "message": f"🚫 You do not have permission to use {cmd}"
            }), file=sys.stderr)
            sys.exit(1)

        # For /model: only allow plain model switching, block config subcommands
        if cmd == "/model":
            config_subcommands = {
                "configure", "set", "add", "remove", "delete",
                "provider", "api-key", "api_key", "base-url", "base_url",
                "system", "personality", "reasoning", "tools", "skill",
            }
            first_arg = parts[1].lower() if len(parts) > 1 else ""

            if first_arg in config_subcommands:
                print(json.dumps({
                    "status": "access_denied",
                    "message": "🚫 You can only switch models, not configure them. Use /model <model-name> only."
                }), file=sys.stderr)
                sys.exit(1)

            if any(p.startswith("--") for p in parts[1:]):
                print(json.dumps({
                    "status": "access_denied",
                    "message": "🚫 You can only switch to an existing model by name. Configuration flags are not allowed."
                }), file=sys.stderr)
                sys.exit(1)

        sys.exit(0)

    # --- Unknown user: block restricted commands ---
    if cmd in ADMIN_ONLY_COMMANDS:
        print(json.dumps({
            "status": "access_denied",
            "message": f"🚫 You do not have permission to use {cmd}"
        }), file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
