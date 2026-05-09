---
description: List configured AgentSpaces and summarize each one's accounts and runbooks
---

1. `list_agent_spaces` — get all spaces the current `AWS_PROFILE` has access to.
2. For each space, `list_associations(agent_space_id=...)` to see which AWS accounts are attached.
3. For each space, briefly probe its knowledge: `create_chat(agent_space_id=...)` → `send_message("Summarize the AWS services and runbooks you have access to. One-paragraph answer.")`. Run these probes concurrently where possible.
4. Print a table: name, agent_space_id, attached account IDs, one-line capability summary.
5. If the user has more than one space and no routing guide exists at `.claude/aws-devops-agent.md`, offer to write one — that's what the `multi-space` skill consults in future sessions.
