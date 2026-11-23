---
name: my-tickets
description: Use when Diego Ramirez asks to see, list or fetch his open ClickUp tickets, his Pipes tickets, his PDIs or bug reports, what is assigned to him in ClickUp outside Pipes, or which of his tickets wait on or block others.
---

# My open tickets

Lists the open ClickUp tickets assigned to Diego Ramirez, grouped by the ClickUp list they live in, with what each
one waits on and blocks. This skill only reads: it never changes a status, priority, assignee, relation or comment,
even when a ticket looks finished.

Steps 0 to 4 are the fetch. `my-tickets-priority` runs them and then writes its own ranked report instead of Step 5.

| Choice | ClickUp list | List id |
| --- | --- | --- |
| **Pipes** | Pipes (Product Engineering (iDerive)) | `901417632447` |
| **Bugs/PDIs** | Bug Reports (same space): `PDI: …` and `BUG: …` tickets | `901417631240` |
| **Others** | any other list (Prod Eng OKRs, sprints, Clients & Services View, …) | everything else |

Workspace id `90141273289`. Diego Ramirez's ClickUp user id is `100891986`.

## Step 0: Preconditions

Load the ClickUp connector tools with this ToolSearch query:

`select:mcp__clickup__clickup_resolve_assignees,mcp__clickup__clickup_filter_tasks,mcp__clickup__clickup_get_list,mcp__clickup__clickup_execute_operator`

Then call `clickup_resolve_assignees(["me"])`. It must return user id `100891986`.

**If ToolSearch finds no ClickUp tools, the call fails, or it returns another user, stop and report which.** If the
connector needs authorization, tell Diego Ramirez to authorize ClickUp in his claude.ai connector settings and end the
turn. Do not fall back to the ClickUp website, `curl`, or the last ticket list you remember.

## Step 1: Ask which lists

If the request already names the lists ("my PDIs", "Pipes and others"), use those. Otherwise ask with exactly this
`AskUserQuestion` call, even when the last review or the conversation so far was about Pipes only:

```json
{"questions": [{
  "question": "Which ClickUp lists do you want to see open tickets from?",
  "header": "Lists",
  "multiSelect": true,
  "options": [
    {"label": "Pipes", "description": "The Pipes list: engineering work, features, tech debt and infra"},
    {"label": "Bugs/PDIs", "description": "The Bug Reports list: PDI data-quality tickets and BUG dashboard reports"},
    {"label": "Others", "description": "Every other list: Prod Eng OKRs, sprints, Clients & Services View and the rest"}
  ]
}]}
```

## Step 2: Fetch

Make one `clickup_filter_tasks` call with `assignees: ["me"]`,
`fields: ["custom_id", "status", "priority", "due_date", "list"]` and no `include_closed`:

- **Others not chosen:** pass `list_ids` with the chosen lists' ids.
- **Others chosen:** pass no `list_ids`, because Others is every list except the two above.

While `has_more` is true, call again with `page: next_page`, because one page is not the whole list. Results always
carry `id`, `name` and `url`.

Then put each task in a bucket by its `list.id`: `901417632447` goes to Pipes, `901417631240` to Bugs/PDIs, and any
other id to Others. Throw away the buckets that weren't chosen.

## Step 3: Keep only open tickets

`completed` is a **done**-type status, and filter calls return done-type tickets even without `include_closed`. So
drop by status *type*, not by name. Call `clickup_get_list` once for each distinct `list.id` left in the chosen buckets.
Keep a task only if its status's `type` is `open` or `custom`. Drop `done` (`completed`, `not relevant`, `user error`)
and `closed`. After that, drop any list that has no tickets left.

## Step 4: Relations

`clickup_filter_tasks` returns no relations. One bulk read returns them for every kept ticket:

```text
clickup_execute_operator(model="task", operator="get_many",
  body={"ids": [<internal ids of the kept tickets>]},
  query="tasks[*].{id: object_id, rel: data.related_tasks, parent: data.direct_parent}")
```

Send at most 50 ids per call. Each `rel` entry has a `task_id` and a `type`:

| `type` | Meaning for this ticket |
| --- | --- |
| `dependsOn` | **waits on** that task |
| `dependedBy` | **blocks** that task |
| `linked` | related, no order |

Subtasks are not relations: `parent` holds the parent task's internal id, or null.

A relation still lists a task that is already done. Resolve every related `task_id` that is not a kept ticket with a
second `get_many` call:

```text
query="tasks[*].{id: object_id, found: status, custom_id: data.custom_id, name: data.name,
                 status: data.status.status, list: data.lists[0].list_id}"
```

That status has no type, so read the type from `clickup_get_list` for its list (Step 3 already has the chosen lists).
A `dependsOn` task whose type is `done` or `closed` no longer blocks: leave it out of **Waits on**. A task that comes
back with a `found` other than `found` is outside the workspace: show its id as text.

## Step 5: Report

Write one section per chosen list (`## Pipes`, `## Bugs/PDIs`, `## Others`). A chosen section with no open tickets
says `0 open tickets.` Under Others, add a `###` sub-heading per ClickUp list name, ordered by open count (most first)
and then by name. Each section has a count and a table:

| Ticket | Title | Status | Priority | Due | Waits on | Blocks |
| --- | --- | --- | --- | --- | --- | --- |
| [ID-28236](https://app.clickup.com/t/86bcfz5yn) | Split the Batch Service DB … | deploying | high | — | [ID-28239](https://app.clickup.com/t/86bcg2ga4) | — |

- **Ticket** is always a link: `[<custom_id>](<url>)`, with the task's `url` from the result. If the task has no
  custom id, use its title as the link text. **Waits on** and **Blocks** use the same link form, built as
  `https://app.clickup.com/t/<task_id>`, and `—` when empty.
- One row per ticket. Don't merge tickets into a shared row.
- A null priority shows as `none`. Sort by priority (urgent, high, normal, low, none), then by status in the list's
  order from `clickup_get_list`.
- Show due dates as `YYYY-MM-DD`, converting epoch ms in `America/Los_Angeles` (the workspace stores a date-only due at
  midnight Pacific). Mark a due date before today `(overdue)`.
- Below each table, list the parent (`subtask of`) and the links (`linked`) as one line per ticket that has any:
  `[ID-28236](…): [ID-28127](…), [ID-28678](…)`.
- After the tables, write one line per list with the counts by status. Stop there: no ranking, no advice, no
  close-out suggestions. When Diego Ramirez asks what to work on, or for a priority review, that is
  `my-tickets-priority`, not this report.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| Counting OKR, sprint or onboarding tickets as Pipes tickets | Pipes means list `901417632447` only. The rest goes under Others. |
| Listing `completed` tickets as open | Drop by status type (`done`, `closed`), not by name. |
| Stopping after the first page | Loop while `has_more`. |
| Skipping Step 1 because the last review was Pipes only | Ask unless this request names the lists. |
| One `clickup_get_task` per ticket for relations | One `task.get_many` per 50 tickets (Step 4). |
| A completed ticket shown under **Waits on** | Drop `dependsOn` tasks whose status type is `done` or `closed`. |
| Plain `ID-28127` in the table | Always link to the task's `url`. |
| Closing or moving a "finished" ticket | This skill is read-only. Diego Ramirez reviews completed tickets himself. |
