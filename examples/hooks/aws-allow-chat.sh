#!/usr/bin/env bash
# PreToolUse hook: auto-approve aws___run_script when the script body
# is a send_message call (the normal chat streaming pattern).
# Matches: mcp__aws__aws___run_script
#
# Install in ~/.claude/settings.json alongside aws-allow-reads.sh:
# {
#   "hooks": {
#     "PreToolUse": [
#       {
#         "matcher": "mcp__aws__aws___call_aws",
#         "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/aws-allow-reads.sh"}]
#       },
#       {
#         "matcher": "mcp__aws__aws___run_script",
#         "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/aws-allow-chat.sh"}]
#       }
#     ]
#   }
# }

set -euo pipefail

input=$(cat)
code=$(echo "$input" | jq -r '.tool_input.code // ""')

# Only auto-approve if the script contains send_message and nothing dangerous
if echo "$code" | grep -q 'client\.send_message(' && \
   ! echo "$code" | grep -qP 'client\.(delete|remove|terminate|put_|create_|update_)'; then
  echo '{"decision": "allow"}'
else
  echo '{}'
fi
