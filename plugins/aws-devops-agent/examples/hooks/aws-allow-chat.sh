#!/usr/bin/env bash
# PreToolUse hook: auto-approve aws___run_script when the script body
# is a send_message call (the normal chat streaming pattern).
# Matches: mcp__plugin_aws-devops-agent_aws-mcp__aws___run_script
#
# Install in ~/.claude/settings.json alongside aws-allow-reads.sh:
# {
#   "hooks": {
#     "PreToolUse": [
#       {
#         "matcher": "mcp__plugin_aws-devops-agent_aws-mcp__aws___call_aws",
#         "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/aws-allow-reads.sh"}]
#       },
#       {
#         "matcher": "mcp__plugin_aws-devops-agent_aws-mcp__aws___run_script",
#         "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/aws-allow-chat.sh"}]
#       }
#     ]
#   }
# }

set -euo pipefail

input=$(cat)
code=$(echo "$input" | jq -r '.tool_input.code // ""')

# Auto-approve when the script is a SendMessage via call_boto3 and contains
# no destructive operation_name.
if echo "$code" | grep -qP "operation_name\s*=\s*['\"]SendMessage['\"]" && \
   ! echo "$code" | grep -qP "operation_name\s*=\s*['\"](Delete|Terminate|Remove|Put|Create|Update)[A-Z]"; then
  echo '{"decision": "allow"}'
else
  echo '{}'
fi
