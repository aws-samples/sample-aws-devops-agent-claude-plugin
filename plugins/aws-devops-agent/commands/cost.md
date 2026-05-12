---
description: Ask the AWS DevOps Agent for cost optimization opportunities, scoped to your local IaC
argument-hint: [optional focus area, e.g. "ECS only" or "across all spaces"]
---

Cost optimization is a chat-first workflow.

1. Read whatever local IaC files are present — CDK stacks, CloudFormation templates, Terraform modules. Don't read the whole repo; pick files referenced from `cdk.json`, `template.yaml`, `*.tf`, `serverless.yml`, etc.
2. If `$ARGUMENTS` mentions "all spaces" / "across accounts" and `aws___call_aws(cli_command="aws devops-agent list-agent-spaces --region us-east-1")` returns more than one, follow the `multi-space` skill's parallel-query pattern. Otherwise pick the primary space.
3. `aws___call_aws(cli_command="aws devops-agent create-chat --agent-space-id SPACE_ID --user-id USER_ID --user-type IAM --region us-east-1")` → `aws___run_script` with `send_message(executionId, content="<IaC context>\n\nAnalyze cost optimization opportunities. $ARGUMENTS")`.
4. Show the response. Ask if the user wants to drill into any specific recommendation, or escalate to a deep investigation for one of them.
