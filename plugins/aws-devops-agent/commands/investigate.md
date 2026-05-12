---
description: Start a deep root-cause investigation on the AWS DevOps Agent and stream progress
argument-hint: [incident description]
---

Use the `investigate` skill workflow.

1. If no AgentSpace is yet known in this session, call `aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1")` and pick the right one (consult `.claude/aws-devops-agent.md` if present; ask the user if multiple plausible candidates).
2. Gather local context — `git log --oneline -10`, dependency manifest, relevant IaC, the error/log the user is looking at — and pack it into the `--description` parameter.
3. `aws___call_aws(cli_command="aws devops-agent create-backlog-task --agent-space-id SPACE_ID --task-type INVESTIGATION --title '$ARGUMENTS' --priority HIGH --description '<local context + question>' --region us-east-1")`.
4. Tell the user investigations take 5–8 minutes and that you'll keep them posted.
5. Poll `aws___call_aws(cli_command="aws devops-agent get-backlog-task --agent-space-id SPACE_ID --task-id TASK_ID --region us-east-1")` every 30–45s; when `IN_PROGRESS` and `executionId` is available, paginate `aws___call_aws(cli_command="aws devops-agent list-journal-records --agent-space-id SPACE_ID --execution-id EXEC_ID --order ASC --next-token TOKEN --region us-east-1")`; summarize each new record to the user using the emoji prefixes from the `investigate` skill.
6. On `COMPLETED`: pull the consolidated summary (`--order DESC --max-results 10`), then `aws___call_aws(cli_command="aws devops-agent list-recommendations --agent-space-id SPACE_ID --task-id TASK_ID --region us-east-1")` → `aws___call_aws(cli_command="aws devops-agent get-recommendation --agent-space-id SPACE_ID --recommendation-id REC_ID --region us-east-1")` for each. Show the user the proposed fix; **do not** auto-apply IaC or commands.

If `$ARGUMENTS` is empty, ask the user for a one-line incident description first.
