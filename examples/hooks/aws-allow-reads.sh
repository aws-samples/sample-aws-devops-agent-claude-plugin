#!/usr/bin/env bash
# PreToolUse hook: auto-approve read-only AWS DevOps Agent CLI calls.
# Matches: mcp__aws-mcp__aws___call_aws
#
# Install in ~/.claude/settings.json:
# {
#   "hooks": {
#     "PreToolUse": [
#       {
#         "matcher": "mcp__aws-mcp__aws___call_aws",
#         "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/aws-allow-reads.sh"}]
#       }
#     ]
#   }
# }

set -euo pipefail

input=$(cat)
cli_command=$(echo "$input" | jq -r '.tool_input.cli_command // ""')

# Extract the operation (e.g. "list-agent-spaces", "get-backlog-task", "create-chat")
operation=$(echo "$cli_command" | grep -oP 'devops-agent\s+\K[a-z]+-[a-z-]+' || true)

case "$operation" in
  list-*|describe-*|get-*)
    echo '{"decision": "allow"}'
    ;;
  *)
    # Fall through to normal approval prompt
    echo '{}'
    ;;
esac
