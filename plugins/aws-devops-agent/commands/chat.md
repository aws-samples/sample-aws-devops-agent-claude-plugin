---
description: Open a chat session with the AWS DevOps Agent and ask a question
argument-hint: [question]
---

Use the `chat` skill workflow.

1. If no AgentSpace is yet known in this session, call `list_agent_spaces` and pick the matching space (prefer the routing guide at `.claude/aws-devops-agent.md` if present; otherwise pick the primary or ask the user).
2. `create_chat(agent_space_id=...)` to get an `executionId` and reuse it for the rest of the conversation.
3. Gather any obviously relevant local context (IaC, dependency manifest, recent git commits) and inject it alongside the question.
4. `send_message(execution_id=..., content="<context>\n\n[Question]\n$ARGUMENTS")` and show the response.
5. Tell the user the `executionId` so they can ask follow-ups in the same chat.

If `$ARGUMENTS` is empty, prompt the user for a question first.
