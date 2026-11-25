---
name: ticket-kickoff
description: Use when Diego Ramirez says to start working on, start preparing, pick up or investigate a ClickUp ticket (ID-<n>) in Pipes, asks to read a ticket and create its local plan file, or to start the design, spec or brainstorming for a ticket.
---

# Ticket kickoff

Turns a ClickUp ticket into its plan directory and runs the design phase: the investigation for a bug, the
brainstorming for a feature. It ends when the design doc is agreed. Writing the implementation plan is the next
skill, `write-ticket-plan`, and only on Diego's go.

The layout and the ClickUp status rules are in `~/Developer/repos/pipes/CLAUDE.md` ("Plans", "ClickUp tickets").
`PLANS` below is `~/Developer/repos/pipes/plans`.

## Step 1: Read the ticket

Load the tools with ToolSearch:
`select:mcp__clickup__clickup_get_task,mcp__clickup__clickup_get_task_comments,mcp__clickup__clickup_update_task`

- `clickup_get_task` with the custom id (`ID-<n>`), `include: ["description", "linked_tasks", "dependencies"]`,
  `expand_statuses: true`. Keep its
  internal `id` and `url`: every link to the ticket is built from them.
- `clickup_get_task_comments` for its comments.
- Read the tickets it links or depends on (`clickup_get_task` each) when the description points to them.

If the connector is missing or needs authorization, stop and tell Diego. Don't fall back to the website.

## Step 2: Find or create the directory

```bash
find ~/Developer/repos/pipes/plans -maxdepth 2 -name 'ID-<n>*'
```

- **Something exists:** reuse it, never make a second directory.
  - An older ticket with one `<TICKET>_<slug>.md` keeps that layout: add the ticket contents and the design to that
    file, don't split it.
  - A directory whose files don't use the three standard names (for example `_implementation_plan.md`): propose
    renaming them to `_ticket.md`, `_design.md` and `_plan.md`, and do it on Diego's yes, so the other skills find
    them.
  - It sits in `todo/` and Diego says to start working on it: `mv` it to `wip/`, fix every path that points at it
    (`grep -rn "plans/todo/ID-<n>" ~/Developer/repos/pipes/plans`), then Step 3.

  Tell Diego which files you are using.
- **Nothing exists:** create the directory with the three files below. Use `wip/` when Diego says to start working
  on the ticket; use `todo/` when he only asks to prepare it for later.

```text
PLANS/<state>/ID-<n>/
  ID-<n>_ticket.md
  ID-<n>_design.md
  ID-<n>_plan.md
```

**`ID-<n>_ticket.md`** holds what ClickUp says, copied, not summarised:

```markdown
# [ID-<n>](<url>): <ticket name>

Design: [ID-<n>_design.md](ID-<n>_design.md) · Plan: [ID-<n>_plan.md](ID-<n>_plan.md)

- Read: <YYYY-MM-DD> · Status: <status> · Priority: <priority> · Assignees: <names> · List: <list>
- Related: [ID-<m>](<url of ID-m>) (<relation: related, waits on, blocks>)

## Description

<the description, verbatim>

## Comments

- <YYYY-MM-DD> <author>: <comment text, verbatim; skip bot noise and PR-link-only comments>
```

**`ID-<n>_design.md`**:

```markdown
# ID-<n> design and spec: <ticket name>

Ticket: [ID-<n>_ticket.md](ID-<n>_ticket.md) · Plan: [ID-<n>_plan.md](ID-<n>_plan.md)

## Status

Updated <YYYY-MM-DD>. Next: <first question or investigation step>.

### Log

- <YYYY-MM-DD>: kickoff, ticket read, directory created.

## Goal

## Investigation        (bugs only: queries, example runs, findings, root cause)

## Approaches           (two or three options with trade-offs, and the one chosen)

## Decisions

## Spec

## Open questions
```

**`ID-<n>_plan.md`**: only the title, the links to the two other files, and `Not written yet: waiting for the
design.` The `## Status` section moves here once the plan exists.

## Step 3: ClickUp status

Moving into `wip/` means work started: set the ticket to `in progress - nectar` with `clickup_update_task`. Skip it
if the ticket already has that status or a later one (`under review - nectar`, `deploying`, `completed`), and say so.
A ticket kept in `todo/` keeps its status. Write nothing else in ClickUp (no comment, no description edit) unless
Diego asks.

## Step 4: Check for colliding work

Before designing, check what else touches the same area, and write the result under `## Status` or `## Open
questions`:

- `gh pr list --base dev --state open` in `~/Developer/repos/pipes/datasource_pipelines`, and any open PR whose
  title or files overlap the ticket. If the work should build on one of those branches, say which and ask.
- `ls PLANS/todo PLANS/wip` for plans on the same tables, connectors or modules.
- The other repos when the ticket mentions them (`python_scripts`, `airflow-dags`, the dbt repo): read them, don't
  assume.

## Step 5: Design

Read the code before proposing anything: run `git fetch origin` and read `origin/dev` (a local `dev` can be days
behind). Read prod and dev data only through the `nectar-db-reader` MCP server, never `psql`, `.env` or `.env.db`.

- **Bug or investigation:** use `superpowers:systematic-debugging`, phases 1 to 3 only. Phase 4 (the fix) becomes
  the plan. Overrides:
  - First check whether the problem still happens.
  - Evidence comes from reads: `nectar-db-reader` queries, run ids, run logs, CloudWatch, a local reproduction.
    Instrumentation or a minimal test that needs a code change, a deploy or a write on a server is proposed to
    Diego and done only on his go.
  - Write each finding and each hypothesis (confirmed or rejected) into `## Investigation` as soon as you have it.
  - Once the root cause is shown, write the fix options into `## Approaches`. With one obvious fix, ask Diego to
    confirm it. With several, use `superpowers:brainstorming` for the fix with the overrides in the next bullet.
- **Feature or change:** use `superpowers:brainstorming`, with these overrides:
  - The spec goes into `ID-<n>_design.md`, never `docs/superpowers/specs/`, and you don't commit it (`plans/` is
    gitignored).
  - Its builder check runs on a fresh `opus` agent.
  - When the design is approved, don't invoke `superpowers:writing-plans`: go to Step 6.
- **Either:** ask Diego the open decisions **one at a time**, each with your recommendation. Write every answer into
  `## Decisions` (decision plus one line of why) in the same turn you get it, not at the end.

Keep the design to what the ticket asks. Name a related improvement once under `## Open questions`, don't design it.

## Step 6: End of design

When Diego agrees the design is complete, update `## Status` with the date and "Design agreed; next: write the
plan", then stop. Tell him the next step is `write-ticket-plan`. Don't write the plan or touch code until he says
so.

## Common mistakes

| Mistake | Instead |
| --- | --- |
| Summarising the ticket description | Copy it verbatim into `_ticket.md`; the plan's executor reads it later. |
| Making a second directory for an existing ticket | Step 2 `find` first; reuse what exists. |
| Splitting an older single-file ticket into three files | Keep its layout. |
| Writing the spec to `docs/superpowers/specs/` | `ID-<n>_design.md`. |
| Asking five decisions in one message | One at a time, each with a recommendation. |
| Logging decisions only at the end | Write each one when Diego answers. |
| Proposing a fix before the root cause is shown | Investigation first, with evidence. |
| Commenting on the ticket or creating follow-up tickets unasked | Only the status change in Step 3. |
| Creating a worktree now | The plan's Task 0 creates it. Only create one now if Diego asks. |
