---
description: Coordinate the AWS DevOps Agent across multiple AgentSpaces from one Claude Code session — route questions to the right space (prod vs staging vs knowledge), query several spaces in parallel and synthesize, or compare findings across accounts. Use whenever the user has more than one AgentSpace configured, mentions multiple AWS accounts, or asks something like "check both prod and staging", "compare across accounts", or "ask the knowledge space".
---

# Querying multiple AgentSpaces

Many real teams run **more than one AgentSpace** — typically a production space, a staging space, and a dedicated "knowledge" space that holds runbooks shared across accounts. Each space has its own set of associated AWS accounts, runbooks, and history.

This skill is the routing brain. Use it when the user has multiple spaces configured, or when a question genuinely spans accounts.

## Discovering spaces

```
aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1") → array of {agentSpaceId, name, ...}
```

If only one space is returned, this skill doesn't apply — use `chat` or `investigate` directly.

If more than one is returned, decide whether the user's question is:

| Question shape | Strategy |
|---------------|----------|
| Scoped to one environment ("prod is broken") | Single space — pick the matching one |
| Spans environments ("compare prod vs staging") | **Parallel** — query each, synthesize |
| Generic knowledge ("what runbooks do we have for ECS?") | Route to the **knowledge** space if one is named that way |
| Ambiguous ("our service is slow") | **Ask the user** which environment, don't guess |

## Per-session routing memory

If the user has a routing guide stored locally (e.g. `.claude/aws-devops-agent.md`, `AGENTS.md`, or per-project notes), read it once at the start of the session and use it as the routing table for the rest of the conversation. Format expected:

```markdown
| Space | AWS Profile | Agent Space ID | Purpose |
|-------|-------------|----------------|---------|
| prod  | acme-prod   | as-abc123      | Production incidents, customer-facing services |
| stage | acme-stage  | as-def456      | Pre-prod validation, integration testing |
| kb    | acme-shared | as-ghi789      | Shared runbooks, cross-account knowledge |
```

If no guide exists, run discovery:
1. `aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1")` → get all spaces.
2. For each space: `aws___call_aws(cli_command="aws devops-agent create-chat --agent-space-id SPACE_ID --user-id USER_ID --user-type IAM --region us-east-1")` → `aws___run_script → send_message(executionId, "Summarize the AWS accounts, services, and runbooks you have access to.")`
3. Offer to write the routing guide to `.claude/aws-devops-agent.md` so future sessions skip discovery.

## Pattern A — Parallel queries, one synthesized answer

Use when the user wants a comparison: "compare prod and staging error rates", "is this issue happening in both accounts?", "audit costs across all our environments".

```
# 1. Open a chat per space (run in parallel where possible)
aws___call_aws(cli_command="aws devops-agent create-chat --agent-space-id PROD_ID --user-id USER_ID --user-type IAM --region us-east-1")  → exec_prod
aws___call_aws(cli_command="aws devops-agent create-chat --agent-space-id STAGE_ID --user-id USER_ID --user-type IAM --region us-east-1") → exec_stage

# 2. Send the same question to each, with environment-specific context
aws___run_script → send_message(exec_prod,  "<question> | env=prod | <prod IaC context>")
aws___run_script → send_message(exec_stage, "<question> | env=stage | <stage IaC context>")

# 3. Synthesize locally — present a side-by-side summary, not two separate dumps
```

**Don't just paste both responses.** Read both, identify what's the same vs. different, and tell the user the *delta* — that's the value.

## Pattern B — Knowledge lookup, then per-space action

Use when one space holds runbooks/knowledge that informs work in another space.

```
# 1. Ask the knowledge space first
aws___call_aws(cli_command="aws devops-agent create-chat --agent-space-id KB_ID --user-id USER_ID --user-type IAM --region us-east-1") → exec_kb
aws___run_script → send_message(exec_kb, "What's our standard runbook for ECS 503 errors?")

# 2. Apply that runbook in the target environment
aws___call_aws(cli_command="aws devops-agent create-backlog-task \
  --agent-space-id PROD_ID \
  --task-type INVESTIGATION \
  --title 'ECS 503 errors on checkout-service' \
  --priority HIGH \
  --description '[Runbook from knowledge space] <runbook text> [Local context] ...' \
  --region us-east-1")
```

The DevOps Agent doesn't share state between spaces — you bridge it by quoting the knowledge space's response into the investigation's `--description`.

## Pattern C — Targeted single-space query

Use when the user explicitly names a space or environment.

```
# Pick the matching agentSpaceId from your routing memory
# Then use aws___call_aws / aws___run_script as normal
```

If the routing is ambiguous and the user doesn't say, **ask once** — better than firing into the wrong account.

## Pattern D — Investigations don't share state

`create-backlog-task` is per-space. If an issue spans accounts, you may need *two* investigations:

```
aws___call_aws(cli_command="aws devops-agent create-backlog-task --agent-space-id PROD_ID --task-type INVESTIGATION --title 'Latency spike — prod side' --priority HIGH --region us-east-1")
aws___call_aws(cli_command="aws devops-agent create-backlog-task --agent-space-id STAGE_ID --task-type INVESTIGATION --title 'Latency spike — stage side' --priority HIGH --region us-east-1")
```

Track both `taskId`s. Poll both. Surface findings together.

This is rare — usually one space owns the problem. Don't fan out by default.

## What NOT to do

- **Don't blast every space with every question.** It's slow, expensive, and the user has to read 3× as much output.
- **Don't fire investigations in parallel by default.** They take 5–8 minutes each. Pick the one space that owns the incident.
- **Don't silently switch spaces mid-conversation.** If a follow-up needs a different space, tell the user: "Switching to the knowledge space to look up the runbook."

## See also

- `examples/multi-space-walkthrough.md` for a fully worked scenario (prod incident with staging comparison and knowledge-space runbook lookup).
- The `setup` skill for first-time configuration of multiple AgentSpaces, AWS profiles, and shell wrappers.
