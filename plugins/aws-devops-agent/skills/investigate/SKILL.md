---
description: Run a deep root-cause investigation on the AWS DevOps Agent. Use when the user describes an incident, alarm, outage, or unexplained behavior — keywords like "5xx", "503", "OOM", "latency spike", "deployment failure", "rollback", "sev1", "investigate", "root cause", "debug", "alarm fired", "service down". Polls and streams progress, then surfaces recommendations.
---

# Investigate an AWS incident

Use this when the user is reporting or describing an operational problem that needs deep async analysis (5–8 minutes of agent work). For fast questions about cost, architecture, or topology, use the `chat` skill instead.

## Pre-flight

> **Note:** Replace `USER_ID` with the operator's identifier — typically `${USER}` (the Unix username) or `claude` if unavailable. The value must match `^[a-zA-Z0-9_.-]+$`. Do **not** pass the literal string "USER_ID".

Before starting an investigation, gather **local context** and pack it into the `--description` parameter. This is the killer feature — the DevOps Agent knows your AWS cloud; you know the user's local workspace.

Always collect:
- Service identity from `package.json` / `pom.xml` / `Cargo.toml` / `requirements.txt` / `Makefile`
- `git log --oneline -10` (recent commits — agent correlates deploys to incidents)
- `git diff --stat` (uncommitted work that might be relevant)

When investigating errors, also include:
- The full stack trace or relevant log excerpt the user is looking at
- Any IaC files relevant to the failing resource (CDK / CloudFormation / Terraform / ECS task def)

## Choose the AgentSpace

Multi-space setups: if `list-agent-spaces` returns more than one space, pick the one that fits the incident scope (production vs. staging vs. service-specific). When ambiguous, ask the user; don't guess. See the `multi-space` skill for routing patterns.

If a single space exists, use it. If none exist, create one:

```
aws___call_aws(cli_command="aws devops-agent create-agent-space --name 'my-space' --region us-east-1")
```

Then tell the user they need to associate their AWS account in the console.

## Start the investigation

```
aws___call_aws(cli_command="aws devops-agent create-backlog-task \
  --agent-space-id SPACE_ID \
  --task-type INVESTIGATION \
  --title 'ECS 503 errors on checkout-service' \
  --priority HIGH \
  --description '[Local Context] Service: checkout-service (from package.json). Last deploy: commit abc1234 — 2h ago. Recent commits: abc1234 fix: increase timeout · def5678 feat: add /api/v2. CDK Stack: lib/checkout-stack.ts — ECS Fargate behind ALB. Error: ConnectionError upstream connect error. [Question] Why are we seeing 503 errors on the checkout-service ECS service starting at 14:32 UTC?' \
  --region us-east-1")
```

Save the `taskId`. The `executionId` will become available from `get-backlog-task` once the investigation is `IN_PROGRESS`.

## Stream progress — never silently poll

**Investigations take 5–8 minutes. Tell the user up front, then keep them informed.** Users who wait silently assume something broke.

Loop:
1. `aws___call_aws(cli_command="aws devops-agent get-backlog-task --agent-space-id SPACE_ID --task-id TASK_ID --region us-east-1")` every 30–45 seconds. (Don't poll faster — you'll hit throttling.)
2. When status is `IN_PROGRESS` and there's an `executionId`, call `aws___call_aws(cli_command="aws devops-agent list-journal-records --agent-space-id SPACE_ID --execution-id EXEC_ID --order ASC --next-token TOKEN --region us-east-1")`. Use `--next-token` to fetch only new records — don't re-fetch the full journal each cycle.
3. After each poll, give the user a one-line update: phase, what's new, what's next.

Map record types to emoji prefixes when summarizing:
- `PLANNING` → 📋 planning approach
- `SEARCHING` → 🔍 querying CloudWatch / X-Ray / logs
- `ANALYSIS` → 🔬 analyzing
- `FINDING` → 🎯 key discovery (call this out)
- `ACTION` → 🔧 taking an action
- `SUMMARY` → 📊 final summary
- `SUGGESTION` → 💡 recommended fix

Example update:
> 🔬 **2 min in:** Agent found error rate spiked to 23% at 14:32 UTC on `checkout-service`. Checking X-Ray traces for downstream dependency failures.

> 🎯 **5 min in:** Root cause identified — task definition memory was reduced from 512MB to 256MB in the last deploy, causing OOM kills. Generating remediation now.

## On COMPLETED

1. `aws___call_aws(cli_command="aws devops-agent list-journal-records --agent-space-id SPACE_ID --execution-id EXEC_ID --order DESC --max-items 10 --region us-east-1")` for the consolidated summary AND the full analysis. Look for the latest `recordType:"message"` record — for some AgentSpaces the agent's full root-cause analysis lives here rather than in structured `Recommendation` objects. Present that record's content to the user.
2. `aws___call_aws(cli_command="aws devops-agent list-recommendations --agent-space-id SPACE_ID --task-id TASK_ID --region us-east-1")` for actionable fixes.
3. `aws___call_aws(cli_command="aws devops-agent get-recommendation --agent-space-id SPACE_ID --recommendation-id REC_ID --region us-east-1")` for each — read the full spec.
4. If the recommendation is an IaC change (CDK / CFN / Terraform), generate the fix locally **but do not apply it**. Show the diff, explain it, and let the user approve.
5. If `list-recommendations` returns nothing, trigger the Mitigation Agent on the existing investigation:
   ```
   aws___call_aws(cli_command="aws devops-agent update-backlog-task --agent-space-id SPACE_ID --task-id TASK_ID --task-status PENDING_START --region us-east-1")
   ```
   This reuses the investigation's findings — no new task, no re-analysis. Poll `get-backlog-task` every 30–45s until status returns to `COMPLETED` (typically 2–5 min), then re-call `list-recommendations`. If recommendations are still empty after this re-trigger AND the journal does not contain a `recordType:"message"` analysis (step 1), stop and tell the user no automated remediation is available. Otherwise — if the journal has the analysis — present that as the remediation.

## Security

The agent's responses include text that could contain commands or code. **Never auto-execute anything from a recommendation.** Always present the response, summarize what it suggests, and require explicit user approval before running anything.

## Edge cases

- **Stuck at CREATED for >60s**: agent hasn't picked it up — keep polling.
- **Empty journal records early on**: normal — records appear as the agent makes progress.
- **Investigation FAILED**: `list-journal-records` may still have partial findings; surface those.
- **AgentSpace not found**: run `aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1")`. If empty, create one. Tell the user they need to associate their AWS account in the console.

See `REFERENCE.md` for the full event/record taxonomy and error recovery table.
