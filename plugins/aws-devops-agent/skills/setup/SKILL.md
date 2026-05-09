---
description: First-time setup of the AWS DevOps Agent for Claude Code — install the binary, configure AWS profiles for one or more AgentSpaces, discover space IDs, write the local routing guide, and verify the MCP server starts. Use when the user says "set up devops agent", "configure agent spaces", "I have multiple AWS accounts", or you detect that credentials / spaces are missing.
---

# First-time setup

Run this skill when:
- The user explicitly asks to set up the DevOps Agent
- A tool call fails with `ExpiredTokenException`, `AccessDeniedException`, or "no AgentSpace found"
- The user mentions multiple AWS accounts and you don't have a routing guide

## Step 1 — Install the binary

```bash
pip install 'aws-devops-agent[mcp]'
which aws-devops-agent          # full absolute path — record this
aws-devops-agent --version      # should print 1.0.0+
```

If `--version` fails, the user has a stale install: `pip install --force-reinstall 'aws-devops-agent[mcp]'`.

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

For each profile, list spaces:

```bash
AWS_PROFILE=devops-prod \
DEVOPS_AGENT_USER_ID=$(whoami) \
DEVOPS_AGENT_REGION=us-east-1 \
python3 -c "from aws_devops_agent import ACPClient; print(ACPClient.quick('List my agent spaces'))"
```

Record the space name and ID for each. If a profile has no space:
- Set `DEVOPS_AGENT_AUTO_CREATE_SPACE=true` and re-run, **or**
- Tell the user to create one in the AWS console and associate the right account.

## Step 5 — Pick the primary space for the MCP server

The MCP server in `.mcp.json` runs against **one** profile/space at a time. Pick the space the user will hit most often (typically production incidents). Other spaces are reachable via shell wrappers (Step 6) or by switching `AWS_PROFILE` and restarting Claude Code.

## Step 6 — Wire it into Claude Code

The plugin's `.mcp.json` reads `AWS_PROFILE`, `DEVOPS_AGENT_USER_ID`, and `DEVOPS_AGENT_REGION` from the environment. Set them in the user's shell rc file:

```bash
# ~/.zshrc or ~/.bashrc
export DEVOPS_AGENT_USER_ID=$(whoami)
export DEVOPS_AGENT_REGION=us-east-1
export AWS_PROFILE=devops-prod   # the primary space
```

Or, for a Claude Code project that should always target a specific space, add the env vars to project-scope settings.

After installing the plugin (`/plugin install aws-devops-agent@aws-devops-tools`), reload: `/reload-plugins`. Verify:

```
list_agent_spaces
```

Should return the spaces in the primary account.

## Step 7 — Shell wrappers for non-primary spaces

For each space that is NOT the MCP primary, generate a wrapper script so the user (or Claude) can hit it from Bash without restarting:

```bash
#!/usr/bin/env bash
# Query the <purpose> AgentSpace
set -euo pipefail
[ $# -eq 0 ] && { echo "Usage: $(basename "$0") \"your question\""; exit 1; }
export AWS_PROFILE=devops-stage
export DEVOPS_AGENT_USER_ID=<username>
export DEVOPS_AGENT_REGION=us-east-1
exec python3 -c "
import sys
from aws_devops_agent import ACPClient
print(ACPClient.quick(sys.argv[1]))
" "$*"
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
1. `list_agent_spaces` returns the primary space's spaces.
2. `create_chat` + `send_message` returns a response within ~10s.
3. A shell wrapper (`devops-stage "list runbooks"`) prints results.
4. The routing guide is loaded at the start of the next session — confirm by asking the user a routing question.

## Common pitfalls

- **`ExpiredTokenException`** at startup → user needs `aws sso login --profile <name>`.
- **MCP server fails to start** → `which aws-devops-agent` empty in the shell Claude Code launches; install in the right Python environment or use absolute path in `.mcp.json`.
- **0 tools after install** → run `/reload-plugins`, then `/plugin list` to confirm the plugin is enabled.
- **Plugin doesn't see env vars** → Claude Code reads the env vars from the shell that *launched* it; restart from a fresh shell after editing rc files.
