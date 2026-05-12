---
description: Open a chat session with the AWS DevOps Agent and ask a question
argument-hint: [question]
---

Use the `chat` skill workflow.

1. If no AgentSpace is yet known in this session, call `aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1")` and pick the matching space (prefer the routing guide at `.claude/aws-devops-agent.md` if present; otherwise pick the primary or ask the user).
2. `aws___call_aws(cli_command="aws devops-agent create-chat --agent-space-id SPACE_ID --region us-east-1")` to get an `executionId` and reuse it for the rest of the conversation.
3. Gather any obviously relevant local context (IaC, dependency manifest, recent git commits) and inject it alongside the question.
4. Use `aws___run_script` with the boto3 streaming pattern (see `chat` skill) to call `send_message` with `content="<context>\n\n[Question]\n$ARGUMENTS"` and show the response.
5. Tell the user the `executionId` so they can ask follow-ups in the same chat.

If `$ARGUMENTS` is empty, prompt the user for a question first.
