---
description: Start a deep root-cause investigation on the AWS DevOps Agent and stream progress
argument-hint: [incident description]
---

Use the `investigate` skill workflow.

1. If no AgentSpace is yet known in this session, call `list_agent_spaces` and pick the right one (consult `.claude/aws-devops-agent.md` if present; ask the user if multiple plausible candidates).
2. Gather local context — `git log --oneline -10`, dependency manifest, relevant IaC, the error/log the user is looking at — and pack it into the `description` parameter.
3. `create_investigation(agent_space_id=..., title="$ARGUMENTS", priority="HIGH", description=<local context + question>)`.
4. Tell the user investigations take 5–8 minutes and that you'll keep them posted.
5. Poll `get_task` every 30–45s; on `IN_PROGRESS` paginate `list_journal_records` with `next_token`; summarize each new record to the user using the emoji prefixes from the `investigate` skill.
6. On `COMPLETED`: pull the consolidated summary (`order=DESC, limit=10`), then `list_recommendations` → `get_recommendation` for each. Show the user the proposed fix; **do not** auto-apply IaC or commands.

If `$ARGUMENTS` is empty, ask the user for a one-line incident description first.
