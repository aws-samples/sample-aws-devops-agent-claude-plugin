# Investigation reference

## Journal record types

| Type | Emoji | Meaning |
|------|-------|---------|
| `PLANNING` | 📋 | Agent is planning its approach |
| `SEARCHING` | 🔍 | Agent is querying CloudWatch, X-Ray, logs, IAM, etc. |
| `ANALYSIS` | 🔬 | Agent is analyzing collected data |
| `FINDING` | 🎯 | Key discovery — surface this prominently |
| `ACTION` | 🔧 | Agent is performing a read-only action |
| `SUMMARY` | 📊 | Investigation summary with root cause |
| `SUGGESTION` | 💡 | Recommended fix |

## Polling cadence

| Status | Action |
|--------|--------|
| `CREATED` | Poll every 30s. Wait up to 60s — if still CREATED, keep waiting. |
| `IN_PROGRESS` | Poll every 30–45s. Fetch journal records with pagination. |
| `COMPLETED` | Stop polling. Fetch full journal `order=DESC limit=10`, then recommendations. |
| `FAILED` | Stop polling. Fetch journal — partial findings often exist. |

Never poll faster than 30s — you'll hit throttling.

## Pagination

`list_journal_records` returns `nextToken` when there are more records. Save it and pass on the next poll so you only fetch *new* records each cycle. Re-fetching the full journal on every poll is wasteful and slow.

## Error recovery

| Error | Cause | Action |
|-------|-------|--------|
| `ResourceNotFoundException` | Wrong agent_space_id | `list_agent_spaces` to verify |
| `ThrottlingException` | Polling too fast | Back off — 60s, then 90s, then 120s |
| `ValidationException` | Missing required field on `create_investigation` | `title` and `priority` are required |
| `AccessDeniedException` | Missing IAM permissions | User needs `AIDevOpsAgentFullAccess` |
| `ExpiredTokenException` | AWS credentials expired | `aws sso login` or refresh access keys |

## Priority guide

| Priority | Use for |
|----------|---------|
| `CRITICAL` | Active sev1, customer-facing outage |
| `HIGH` | Active production incident, error rate elevated |
| `MEDIUM` | Recurring issue, performance degradation |
| `LOW` | Postmortem, follow-up mitigation generation |
| `MINIMAL` | Exploratory analysis, no time pressure |

## Common patterns

### Parallel triage + investigation

When the user reports an incident, fire **both** in sequence so they get instant guidance while the deep investigation runs:

```
create_chat() → executionId
send_message(executionId, "<incident> + <local context>") → instant triage (2-10s)

create_investigation(title="<incident>", priority="HIGH") → taskId
poll get_task → list_journal_records → deep root cause (5-8 min)
```

Show the chat response immediately. Update the user with investigation progress as journal records come in.

### Generate remediation only

If a previous investigation completed without recommendations:

```
create_investigation(
    title="Generate mitigations for task <prior-task-id>",
    priority="LOW",
    description="The prior investigation identified <root cause>. Generate IaC remediation."
)
```
