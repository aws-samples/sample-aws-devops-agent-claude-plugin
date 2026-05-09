# aws-devops-tools — Claude Code marketplace

A Claude Code marketplace that bundles the [AWS DevOps Agent](https://docs.aws.amazon.com/devopsagent/latest/userguide/) into Claude Code as an installable plugin.

## What you get

The `aws-devops-agent` plugin gives Claude Code:

- **An MCP server** with 19 tools for the AWS DevOps Agent (investigations, chat, recommendations, AgentSpaces, journal records).
- **Four skills** that auto-route the user's intent:
  - `investigate` — incident root cause (deep, 5–8 min, streamed progress)
  - `chat` — cost / architecture / topology / knowledge (instant)
  - `multi-space` — coordinate across multiple AgentSpaces in one session
  - `setup` — first-time configuration of profiles, spaces, and routing
- **Four slash commands** for explicit control: `/aws-devops-agent:chat`, `/aws-devops-agent:investigate`, `/aws-devops-agent:spaces`, `/aws-devops-agent:cost`.
- **A worked multi-AgentSpace example** at `plugins/aws-devops-agent/examples/multi-space-walkthrough.md`.

## Install

Prerequisite: the AWS DevOps Agent CLI must be on `PATH`.

```bash
pip install 'aws-devops-agent[mcp]'
```

Then in Claude Code:

```
/plugin marketplace add awslabs/aws-devops-agent-claude-plugin
/plugin install aws-devops-agent@aws-devops-tools
/reload-plugins
```

(Replace `awslabs/aws-devops-agent-claude-plugin` with wherever this marketplace lives once published.)

## Try it

```bash
# In your shell, before launching Claude Code:
export DEVOPS_AGENT_USER_ID=$(whoami)
export DEVOPS_AGENT_REGION=us-east-1
export AWS_PROFILE=<your-aws-profile>
```

Then in Claude Code:

- `list_agent_spaces` — should return your spaces.
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
│       ├── .mcp.json                    # MCP server wired to DEVOPS_AGENT_* env
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

Apache-2.0.

## Inspiration

The structure and intent-routing approach is adapted from the [Kiro Powers](https://github.com/kirodotdev/powers/tree/main/aws-devops-agent) project, decomposed into Claude Code's plugin / skill / command primitives.
