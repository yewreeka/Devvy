#!/bin/bash
# Session initialization hook for Devvy.
# Lightweight — just surfaces simulator state. /setup configures lazily.

SIMULATOR_ID_FILE="$CLAUDE_PROJECT_DIR/.claude/.simulator_id"

if [ -f "$SIMULATOR_ID_FILE" ]; then
    SIM_ID=$(cat "$SIMULATOR_ID_FILE")
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Devvy session ready. Simulator $SIM_ID is cached. Use /run to build and launch, or /build to compile only."
  }
}
EOF
else
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Devvy session started. No simulator cached yet — /run or /setup will pick one and cache it."
  }
}
EOF
fi

exit 0
