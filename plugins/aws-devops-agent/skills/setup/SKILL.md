---
description: First-time setup of the AWS DevOps Agent for Claude Code — install the binary, configure AWS profiles for one or more AgentSpaces, discover space IDs, write the local routing guide, and verify the MCP server starts. Use when the user says "set up devops agent", "configure agent spaces", "I have multiple AWS accounts", or you detect that credentials / spaces are missing.
---

# First-time setup

Run this skill when:
- The user explicitly asks to set up the DevOps Agent
- A tool call fails with `ExpiredTokenException`, `AccessDeniedException`, or "no AgentSpace found"
- The user mentions multiple AWS accounts and you don't have a routing guide

## Step 1 — Install prerequisites

The plugin uses the **AWS MCP Server** (`uvx mcp-proxy-for-aws`) which is fetched automatically via `uvx`. Verify `uv` is installed:

```bash
uv --version            # should print 0.4.0+
uvx mcp-proxy-for-aws@latest --help   # fetches and runs — no pip install needed
```

If `uv` is missing, install it: `curl -LsSf https://astral.sh/uv/install.sh | sh`

Verify AWS credentials are configured:
```bash
aws sts get-caller-identity   # should return your account/user info
```

If credentials are missing or expired: `aws sso login` (SSO) or `aws configure` (access keys).

## Step 2 — Gather account info

Ask the user **once**, listing what's needed:

> What AWS accounts hold your AgentSpaces? For each, tell me:
> 1. AWS account ID
> 2. Region (default `us-east-1`)
> 3. Purpose (e.g. "production", "staging", "shared knowledge")

## Step 3 — Configure one AWS profile per account

Use named profiles in `~/.aws/config`. The naming convention is the *purpose* — not the account ID — so future references stay readable.

```ini
# ~/.aws/config
[profile devops-prod]
region = us-east-1

[profile devops-stage]
region = us-east-1

[profile devops-kb]
region = us-east-1
```

Then attach credentials:
- **SSO** (recommended): `aws configure sso --profile devops-prod`
- **Access keys**: `aws configure --profile devops-prod`
- **IAM Identity Center**: edit `~/.aws/config` to add `sso_session`, `sso_account_id`, `sso_role_name`

Verify each profile:
```bash
AWS_PROFILE=devops-prod aws sts get-caller-identity
```

## Step 4 — Discover AgentSpace IDs

For each profile, list spaces using the AWS CLI:

```bash
AWS_PROFILE=devops-prod aws devops-agent list-agent-spaces --region us-east-1
```

Record the space name and ID for each. If a profile has no space:
- Run `AWS_PROFILE=devops-prod aws devops-agent create-agent-space --name 'my-prod-space' --region us-east-1` to create one, **or**
- Tell the user to create one in the AWS console and associate the right account.

## Step 5 — Configure the MCP server

Add the AWS MCP Server to Claude Code's MCP configuration (typically `~/.claude/settings/mcp.json` or the project-level `.mcp.json`):

```json
{
  "mcpServers": {
    "aws-mcp": {
      "command": "uvx",
      "timeout": 100000,
      "transport": "stdio",
      "args": [
        "mcp-proxy-for-aws@latest",
        "https://aws-mcp.us-east-1.api.aws/mcp",
        "--metadata", "AWS_REGION=us-east-1"
      ]
    }
  }
}
```

Change `AWS_REGION=us-east-1` in `--metadata` if your AgentSpaces are in a different region.

## Step 6 — Wire credentials into Claude Code

The AWS MCP Server reads credentials from the standard AWS credential chain. Set the primary profile in your shell rc file:

```bash
# ~/.zshrc or ~/.bashrc
export AWS_PROFILE=devops-prod   # the primary space's profile
```

Or set it project-scoped for a Claude Code project that should always target a specific space.

After installing the plugin (`/plugin install aws-devops-agent@aws-devops-tools`), reload: `/reload-plugins`. Verify the tools are available — you should see `aws___call_aws` and `aws___run_script` in `/tools`.

## Step 7 — Shell wrappers for non-primary spaces

For each space that is NOT the MCP primary, generate a wrapper script so the user can query it from the terminal:

```bash
#!/usr/bin/env bash
# Query the staging AgentSpace
set -euo pipefail
SPACE_ID="as-def456"   # staging agent space ID
REGION="us-east-1"
[ $# -eq 0 ] && { echo "Usage: $(basename "$0") \"your question\""; exit 1; }

# Create a chat session and send the message
EXEC_ID=$(AWS_PROFILE=devops-stage aws devops-agent create-chat --user-id $USER_ID --user-type IAM \
  --agent-space-id "$SPACE_ID" --region "$REGION" \
  --query 'executionId' --output text)

AWS_PROFILE=devops-stage python3 - "$EXEC_ID" "$SPACE_ID" "$REGION" "$*" <<'EOF'
import sys, boto3
exec_id, space_id, region, content = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
client = boto3.client('devops-agent', region_name=region)
response = client.send_message(agentSpaceId=space_id, executionId=exec_id, userId='claude', content=content)
full = []
current = None
for event in response['events']:
    if 'contentBlockStart' in event:
        current = event['contentBlockStart'].get('type')
    elif 'contentBlockDelta' in event and current in (None, 'text'):
        delta = event['contentBlockDelta'].get('delta', {})
        if 'textDelta' in delta:
            full.append(delta['textDelta']['text'])
    elif 'contentBlockStop' in event:
        current = None
print(''.join(full))
EOF
```

Install at `~/.local/bin/devops-stage` (and `chmod +x`). Repeat per non-primary space.

## Step 8 — Write the routing guide

This is the file the `multi-space` skill reads at the start of every future session. Default location: `.claude/aws-devops-agent.md` (project-scoped) or `~/.claude/AGENTS.md` (user-scoped).

```markdown
# AWS DevOps Agent — local setup

## AgentSpaces

| Space | Account | AWS Profile | Agent Space ID | Region | Purpose |
|-------|---------|-------------|----------------|--------|---------|
| **prod**  | 111111111111 | `devops-prod`  | `as-abc123` | us-east-1 | Production incidents, customer-facing services |
| **stage** | 222222222222 | `devops-stage` | `as-def456` | us-east-1 | Pre-prod validation, integration testing |
| **kb**    | 333333333333 | `devops-kb`    | `as-ghi789` | us-east-1 | Shared runbooks, cross-account knowledge |

## MCP primary

Plugin MCP server targets **prod** (`AWS_PROFILE=devops-prod`).

## Reaching other spaces

- `devops-stage "your question"` (shell wrapper)
- `devops-kb "your question"` (shell wrapper)
- Or restart Claude Code with `AWS_PROFILE=<other>` exported.

## Credential refresh

When you see `ExpiredTokenException`:
- SSO: `aws sso login --profile <profile>`
- Access keys: `aws configure --profile <profile>`
```

## Step 9 — Verify end-to-end

In Claude Code:
1. `aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1")` returns the primary space's spaces.
2. `aws___call_aws(cli_command="aws devops-agent create-chat --agent-space-id SPACE_ID --user-id USER_ID --user-type IAM --region us-east-1")` returns an `executionId`.
3. `aws___run_script` with a `send_message` call returns a response within ~10s.
4. A shell wrapper (`devops-stage "list runbooks"`) prints results.
5. The routing guide is loaded at the start of the next session — confirm by asking the user a routing question.

## Common pitfalls

- **`ExpiredTokenException`** at startup → user needs `aws sso login --profile <name>`.
- **MCP server fails to start** → `uvx` not found or not in PATH; install `uv` first. Or check `aws sts get-caller-identity` to confirm credentials are valid.
- **`MCP error -32000: Connection closed`** → Most commonly missing/expired AWS credentials. Run `aws sts get-caller-identity` to verify, then `aws sso login` to refresh. Also check that `uvx` is in your PATH.
- **0 tools after install** → run `/reload-plugins`, then `/tools` to confirm `aws___call_aws` appears.
- **Plugin doesn't see env vars** → Claude Code reads the env vars from the shell that *launched* it; restart from a fresh shell after editing rc files.
- **`User identity could not be resolved`** / **`Missing required parameter: userId`** on `create-chat` or `send_message` → both APIs require explicit identity arguments:
  - `create-chat` requires `--user-id <name> --user-type IAM|IDC|IDP`
  - `send_message` requires `userId=<name>`
  For Isengard or direct IAM credentials use `--user-type IAM` and pass any string matching `[a-zA-Z0-9_.-]+` as `--user-id` (e.g. your Unix username). For SSO/Identity Center use `--user-type IDC` after `aws sso login`. Alternatively, use `SendMessage` on investigation `executionId`s from `create-backlog-task` which works with any credential type.
