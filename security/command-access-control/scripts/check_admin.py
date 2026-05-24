#!/usr/bin/env python3
import os
import sys
import json

# --- Configuration ---
# List of authorized Telegram User IDs (as strings)
ADMIN_USER_IDS = {"826307909"}  # <-- Your ID is here

# List of commands with special permission handling
SPECIAL_HANDLING_COMMANDS = {"/model"}
# --- End Configuration ---

def main():
    """
    This is a pre-command hook script for Hermes Agent.
    It implements tiered permissions for specific commands.
    - Admins can use all commands and options.
    - Other users can only use /model to switch models, not advanced flags like --provider.
    """
    command_raw = os.getenv("HERMES_COMMAND_TEXT", "").strip()
    user_id = os.getenv("HERMES_USER_ID")
    
    if not command_raw or not user_id:
        sys.exit(0) # Allow if context is missing

    parts = command_raw.split()
    command = parts[0].lower()

    if command in SPECIAL_HANDLING_COMMANDS:
        # Admins always have permission
        if user_id in ADMIN_USER_IDS:
            sys.exit(0)

        # --- Logic for non-admin /model command ---
        # Check for any arguments starting with '-'
        has_flags = any(p.startswith('-') for p in parts[1:])

        if has_flags:
            # Deny if a non-admin tries to use advanced flags
            error_message = {
                "status": "access_denied",
                "message": f"🚫 You do not have permission to use advanced flags (like --provider) for the {command} command. You can only switch models.",
            }
            print(json.dumps(error_message), file=sys.stderr)
            sys.exit(1) # Block command
        else:
            # Allow commands without flags (e.g., /model, /model claude-sonnet-4)
            sys.exit(0)

    # Allow all other commands by default
    sys.exit(0)

if __name__ == "__main__":
    main()
