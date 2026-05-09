# Worked example — querying multiple AgentSpaces from one Claude Code session

This walkthrough shows the multi-AgentSpace pattern end-to-end: a production incident where the right answer requires data from a **prod** space, a comparison against **staging**, and a runbook from a shared **knowledge** space.

## The setup

The user has three AgentSpaces in three accounts:

| Space | AWS Profile | Agent Space ID | Purpose |
|-------|-------------|----------------|---------|
| **prod**  | `devops-prod`  | `as-prod-001`  | Customer-facing services |
| **stage** | `devops-stage` | `as-stage-002` | Pre-prod validation |
| **kb**    | `devops-kb`    | `as-kb-003`    | Shared runbooks |

The plugin's MCP server is wired against `AWS_PROFILE=devops-prod`, so prod space tools work in-session. The other two are reachable via shell wrappers (`devops-stage`, `devops-kb`) installed during setup.

The routing guide lives at `.claude/aws-devops-agent.md` and the model loaded it at session start.

## The user's question

> Our checkout-service is throwing 503s in prod. Was this happening in staging? And do we have a runbook for ECS 503s?

This is a **three-space question**:
1. Investigate the prod issue (deep, MCP)
2. Check staging for the same pattern (chat, shell wrapper)
3. Pull the standard runbook (chat, shell wrapper)

## What Claude does

### Step 1 — Hand the user instant triage from the knowledge space

Runbooks come back in seconds and inform everything else, so fetch first.

```bash
devops-kb "What's our standard runbook for ECS 503 errors? Give me the diagnostic checklist."
```

Show the runbook to the user. Capture it for the investigation `description`.

### Step 2 — Open the prod investigation in parallel with the staging check

Don't serialize — the investigation takes 5–8 minutes; the staging chat takes seconds. Fire both, then keep both progressing.

**Prod (MCP, deep):**
```
create_investigation(
    agent_space_id="as-prod-001",
    title="ECS 503 errors on checkout-service (prod)",
    priority="HIGH",
    description="""
[Runbook from kb space]
<runbook text>

[Local context]
Service: checkout-service
Last deploy: commit abc1234 (2h ago)
Recent commits: abc1234 fix: increase timeout · def5678 feat: add /api/v2
CDK Stack: lib/checkout-stack.ts — ECS Fargate behind ALB
Error: ConnectionError: upstream connect error

[Question]
Why are we seeing 503 errors on checkout-service starting 14:32 UTC?
"""
)
→ taskId = "task-1234"
```

Tell the user: investigation started, ETA 5–8 min, you'll keep them posted.

**Staging (shell wrapper, fast):**
```bash
devops-stage "Has checkout-service shown elevated 503 rates in the last 24h? Compare to its baseline."
```

Show the staging answer right away — usually 2–10s.

### Step 3 — Synthesize the staging vs prod delta

If staging is **clean**: tell the user "staging is fine — this is prod-specific, likely tied to the recent deploy or prod-only config."

If staging is **also affected**: the issue isn't environment-specific; this is a code or config bug that shipped to both. Tell the user; the investigation should focus on what changed.

If staging hasn't been deployed yet with the new code: explicitly call that out — the deltas are an experiment, not a comparison.

### Step 4 — Stream the prod investigation

While the user reads the staging summary, keep polling `get_task(taskId)` and surfacing journal records:

> 🔍 **2 min in:** Agent is querying CloudWatch metrics for `checkout-service`. Found a 23% error rate spike at 14:32 UTC.

> 🔬 **4 min in:** Cross-referencing X-Ray traces — downstream calls to `payment-service` are timing out. Latency p99 jumped from 200ms to 8s.

> 🎯 **6 min in:** Root cause: the ALB security group blocking `checkout-service` → `payment-service` was tightened in commit `def5678`. Connection pool exhaustion follows.

### Step 5 — Recommendations + remediation

```
list_recommendations(task_id="task-1234")
→ recommendation_id "rec-789"

get_recommendation(recommendation_id="rec-789")
→ Spec for restoring the security group rule (CDK change)
```

Generate the CDK diff locally. **Show it; don't apply it.** Ask the user to review and apply themselves.

### Step 6 — Followup — verify in staging before prod rollback

Suggest the user replay the runbook's verification steps in staging once the fix lands there, before rolling forward in prod. The runbook (from kb) has the steps; quote them inline.

## What this demonstrates

| Pattern | Where it showed up |
|---------|-------------------|
| Knowledge space → primary investigation | Step 1 → 2 (runbook injected into `description`) |
| Parallel chat + investigation | Step 2 (staging chat alongside prod investigation) |
| Staging vs prod synthesis | Step 3 (delta, not raw output) |
| Streaming progress to the user | Step 4 (no silent polling) |
| Recommendation as a proposal, not an action | Step 5 (show, don't apply) |

## Anti-patterns avoided

- ❌ Fanning out an investigation to all three spaces by default (waste of time)
- ❌ Pasting the staging response and the prod response side-by-side without synthesis
- ❌ Auto-running the CDK change from the recommendation
- ❌ Going silent for 6 minutes while the investigation runs
