# aws-devops-tools — Claude Code marketplace

A Claude Code marketplace that bundles the [AWS DevOps Agent](https://docs.aws.amazon.com/devopsagent/latest/userguide/) into Claude Code as an installable plugin.

## What you get

The `aws-devops-agent` plugin gives Claude Code:

- **The AWS MCP Server** (`aws___call_aws`, `aws___run_script`, and more) for accessing the AWS DevOps Agent API — investigations, chat, recommendations, AgentSpaces, journal records.
- **Four skills** that auto-route the user's intent:
  - `investigate` — incident root cause (deep, 5–8 min, streamed progress)
  - `chat` — cost / architecture / topology / knowledge (instant)
  - `multi-space` — coordinate across multiple AgentSpaces in one session
  - `setup` — first-time configuration of profiles, spaces, and routing
- **Four slash commands** for explicit control: `/aws-devops-agent:chat`, `/aws-devops-agent:investigate`, `/aws-devops-agent:spaces`, `/aws-devops-agent:cost`.
- **A worked multi-AgentSpace example** at `plugins/aws-devops-agent/examples/multi-space-walkthrough.md`.

## Install

Prerequisite: `uv` must be on `PATH` (the AWS MCP Server is fetched via `uvx`).

```bash
# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# Verify the MCP proxy works (fetches on first run)
uvx mcp-proxy-for-aws@latest --help
```

Then in Claude Code:

```
/plugin marketplace add aws-samples/aws-devops-agent-claude-plugin
/plugin install aws-devops-agent@aws-devops-tools
/reload-plugins
```

## Try it

```bash
# In your shell, before launching Claude Code:
export AWS_PROFILE=<your-aws-profile>
aws sso login   # or: aws configure
```

Then in Claude Code:

- `aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1")` — should return your spaces.
- "Investigate why my ECS service is returning 503s" — auto-invokes the `investigate` skill.
- "What runbooks does the agent have?" — auto-invokes `chat`.
- `/aws-devops-agent:spaces` — list your AgentSpaces explicitly.

## Multiple AgentSpaces

If you have more than one AgentSpace (e.g. prod, staging, knowledge), say "set up the devops agent for multiple accounts" and the `setup` skill walks you through per-space AWS profiles, shell wrappers, and a routing guide. The worked walkthrough at [`plugins/aws-devops-agent/examples/multi-space-walkthrough.md`](plugins/aws-devops-agent/examples/multi-space-walkthrough.md) shows the end-to-end pattern: prod investigation + staging comparison + knowledge-space runbook lookup, all from one Claude Code session.

## Repo layout

```
.
├── .claude-plugin/
│   └── marketplace.json                # this catalog
├── plugins/
│   └── aws-devops-agent/                # the plugin
│       ├── .claude-plugin/plugin.json
│       ├── .mcp.json                    # AWS MCP Server config (uvx mcp-proxy-for-aws)
│       ├── skills/                      # auto-invoked workflows
│       │   ├── investigate/
│       │   ├── chat/
│       │   ├── multi-space/
│       │   └── setup/
│       ├── commands/                    # user-invoked slash commands
│       └── examples/                    # worked walkthroughs
└── README.md                            # this file
```

## Local development

Test the plugin without publishing:

```bash
git clone <this-repo> claude-aws-devops-agent
claude --plugin-dir ./claude-aws-devops-agent/plugins/aws-devops-agent
```

Or load the whole marketplace:

```
/plugin marketplace add ./claude-aws-devops-agent
/plugin install aws-devops-agent@aws-devops-tools
```

After editing skills or commands, run `/reload-plugins` to pick up changes.

Validate before pushing:

```bash
claude plugin validate ./claude-aws-devops-agent
```

## Contributing

PRs welcome. Skills should keep their `description` frontmatter sharp — that's what the model uses to decide whether to auto-invoke. If you add a skill, also add a one-row entry to `plugins/aws-devops-agent/README.md`.

## License

MIT-0. See [LICENSE](LICENSE).

## Inspiration

The structure and intent-routing approach is adapted from the [Kiro Powers](https://github.com/kirodotdev/powers/tree/main/aws-devops-agent) project, decomposed into Claude Code's plugin / skill / command primitives.
