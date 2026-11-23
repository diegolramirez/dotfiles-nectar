---
name: my-tickets-priority
description: Use when Diego Ramirez asks what he should work on now or next, for a priority review of his ClickUp tickets, to rank or reorder them, or whether their ClickUp priorities still fit.
---

# My tickets priority review

Ranks Diego Ramirez's open ClickUp tickets into a work order and keeps it in one living file:
`~/Developer/repos/pipes/plans/wip/PRIORITY_REVIEW/PRIORITY_REVIEW.md`. Each run refreshes that file. It reads
everything live and proposes ClickUp changes, but writes them only after Diego says go.

## Step 1: Fetch the tickets

**REQUIRED SUB-SKILL:** run `my-tickets` Steps 0 to 4, including its Step 1 question about which lists.
Skip its Step 5 report: this skill writes its own. You now have each ticket's status, priority, due date, **Waits on**,
**Blocks** and links.

## Step 2: Gather the live facts

Every fact in the file comes from one of these, read in this run:

| Fact | Source |
| --- | --- |
| Status, priority, relations, description | ClickUp (Step 1; `clickup_get_task` with `include: ["description"]` for a ticket you haven't read) |
| PR open, merged or draft; review state (run `gh` in `~/Developer/repos/pipes/datasource_pipelines`) | `gh pr list --author @me --state open`, `gh pr view <n>` |
| Shipped to prod or only on `dev` | `gh pr list --base main --state merged --limit 5` and the release file in `plans/wip/RELEASE_*` |
| Next step and open items | the ticket's plan: `find ~/Developer/repos/pipes/plans/todo ~/Developer/repos/pipes/plans/wip -name '<TICKET>*'`, then its unchecked `- [ ]` lines |

For git state, run `git fetch origin` (it moves only the remote refs) and compare `origin/main` with `origin/dev`.
A local `dev` or `main` can be days behind. A file under `plans/done/` is history. Use it to see what changed, never as the current state. A plan's claim
about a PR or a release is checked against `gh`.

With more than 15 tickets to read, send them to fresh `haiku` agents, about 10 tickets each. Each agent returns one
line per ticket: what is open, the next step, any date, and who is waiting.

## Step 3: Rank

Put each ticket in the first tier it matches. The ClickUp priority is an input, not the order.

| Tier | A ticket goes here when |
| --- | --- |
| **1. Now** | Prod is losing data or failing now · a merged fix is on `dev` but not on prod · a date inside 7 days (a scheduled run, a capacity limit, a client date) · a secret or permission exposed now · alerting that doesn't fire · someone is waiting on Diego for a short check |
| **2. In flight and enablers** | Status in progress, under review or deploying, or an open PR (finish before starting new work) · it blocks other open tickets (more blocked tickets ranks higher) |
| **3. Chains by theme** | Everything else with a spec. Group by area; inside a group, follow **Waits on** |
| **4. Waiting on others** | Diego's side is done; the next step belongs to someone else (name the person) |
| **5. Backlog** | Low priority, no spec, or it needs a repro first |

Order inside **Now** by the harm of waiting one more day: data being lost or a secret exposed first, then the nearest
date, then the rest. ClickUp priority doesn't reorder Now. In the other tiers, order by: already in progress, then
ClickUp priority, then the smaller job. A ticket with an open **Waits on** goes in Now only right after its blocker.

The tier sets the priority the ticket should have in ClickUp:

| Tier | Expected priority |
| --- | --- |
| Now | urgent or high |
| In flight, chains, waiting on others | high or normal; urgent only if it is in Now |
| Backlog | low or normal |

## Step 4: Propose ClickUp changes

List every mismatch you found as a row: **Ticket | Now | Proposed | Why**. That covers:

- a priority outside its tier's expected range (Step 3), or no priority at all
- a duplicate, or a ticket that's already done
- a missing relation: "waiting on" only when the plan says the ticket can't start or finish without the other; a
  preferred order is a link

Ask Diego which rows to apply. Apply only those, then record them under "Applied in ClickUp".

## Step 5: Write the file

Read the existing file first. If there is none, this is the first run: compare against the newest
`plans/done/PRIORITY_REVIEW_*` snapshot for "Changed since last run" and start the Applied log empty. Then rewrite
the file with these sections, in this order:

1. `# Ticket priority review` and one line: run date and time, the lists covered, the open ticket count.
2. `## Changed since last run`: tickets completed, new, or with a changed priority or status; tickets that moved tier.
3. One `##` section per tier from Step 3. Each has a table: **# | Ticket | Priority | Status | Waits on | Next step | Why here**.
   Tier 3 adds a **Theme** column after **Ticket**. One row per ticket, numbered across the whole file.
4. `## Proposed ClickUp changes`: the Step 4 rows not applied yet.
5. `## Applied in ClickUp`: a dated log. Keep the old entries and add the new ones.

Every ticket id is a link: `[ID-28127](https://app.clickup.com/t/86bccxj9t)`.

## Step 6: Reply

Give the top 3 to 5 Now items with one line each on why, then the decisions Diego needs to make, then the file path.
Don't paste the whole file into the reply.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| Skipping the list question because the last review was Pipes only | `my-tickets` Step 1 asks unless this request names the lists. |
| Taking PR or release state from a plan or from `plans/done/` | Check `gh`. |
| Ordering by ClickUp priority alone | Tier first (Step 3). Propose a priority change when the tier and the priority disagree. |
| An exposed secret last in Now because its priority is normal | Now is ordered by harm per day, not priority. |
| Comparing `origin/main` with a local `dev` | Compare `origin/main` with `origin/dev` after `git fetch origin`. |
| Putting a blocked ticket in Now | Its blocker comes first, or it waits. |
| Several tickets in one row | One row per ticket. |
| Mentioning a priority change in passing | Add it as a row in "Proposed ClickUp changes". |
| Changing ClickUp without a go | Propose, ask, then apply only what Diego approved. |
