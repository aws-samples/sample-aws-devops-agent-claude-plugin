---
description: List configured AgentSpaces and summarize each one's accounts and runbooks
---

1. `aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1")` — get all spaces the current `AWS_PROFILE` has access to.
2. For each space, `aws___call_aws(cli_command="aws devops-agent list-associations --agent-space-id SPACE_ID --region us-east-1")` to see which AWS accounts are attached.
3. For each space, briefly probe its knowledge: `aws___call_aws(cli_command="aws devops-agent create-chat --agent-space-id SPACE_ID --region us-east-1")` → `aws___run_script` with `send_message(executionId, "Summarize the AWS services and runbooks you have access to. One-paragraph answer.")`. Run these probes concurrently where possible.
4. Print a table: name, agentSpaceId, attached account IDs, one-line capability summary.
5. If the user has more than one space and no routing guide exists at `.claude/aws-devops-agent.md`, offer to write one — that's what the `multi-space` skill consults in future sessions.
