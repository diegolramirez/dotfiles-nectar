---
name: pipes-standup-report
description: Use when Diego Ramirez asks for his Pipes weekly stand-up report, what he worked on since the last stand-up, or a weekly status or project-manager update covering his GitHub PRs, ClickUp tickets and plans.
---

# Pipes weekly stand-up report

Collect everything Diego Ramirez worked on since the last Pipes weekly stand-up from three sources, GitHub, ClickUp and
the local plans, and relate them to each other. Then write one markdown report and save it under `plans/` (`~/Developer/repos/pipes/datasource_pipelines/plans`).
The stand-up is every **Thursday at 08:30 America/Los_Angeles**.

This skill only reads. It never changes ClickUp statuses, moves plans or posts comments. Mismatches go in the
report as suggestions, and the reply offers to apply them.

## Step 0: Preconditions

```bash
command -v gh >/dev/null 2>&1 && echo "gh installed: ok" || echo "gh installed: MISSING"
gh auth status >/dev/null 2>&1 && echo "gh auth:      ok" || echo "gh auth:      FAILED"
PLANS="$HOME/Developer/repos/pipes/datasource_pipelines/plans"
test -d "$PLANS" && echo "plans dir:    ok" || echo "plans dir:    MISSING"
```

Then load the ClickUp MCP tools with this ToolSearch query:

`select:mcp__clickup__clickup_resolve_assignees,mcp__clickup__clickup_filter_tasks,mcp__clickup__clickup_get_task`

Call `clickup_resolve_assignees(["me"])`. Diego Ramirez's ClickUp user id is `100891986`.

The shell is zsh. Quote every glob that is meant for a tool rather than for the shell, for example
`--include='*.md'`. Never start an `echo` argument with `=`.

**If any check fails, stop and report which one.** Do not run `gh auth login` or touch credentials. If the ClickUp
connector needs authorization, tell Diego Ramirez to authorize it in his claude.ai connector settings. Do not produce a
report without ClickUp.

## Step 1: The window

The window starts at the most recent Thursday 08:30 Pacific time that is not in the future, and ends now. Compute
it with the real timezone, since PST and PDT change over the year:

```bash
read -r START_UTC START_MS START_DATE END_DATE <<<"$(python3 - <<'PY'
from datetime import datetime, timedelta, time, timezone
from zoneinfo import ZoneInfo
la = ZoneInfo("America/Los_Angeles")
now = datetime.now(la)
start = datetime.combine(now.date() - timedelta(days=(now.weekday() - 3) % 7), time(8, 30), la)
if start > now:
    start -= timedelta(days=7)
s = start.astimezone(timezone.utc)
print(s.strftime("%Y-%m-%dT%H:%M:%SZ"), int(s.timestamp() * 1000), start.strftime("%Y%m%d"), now.strftime("%Y%m%d"))
PY
)"; echo "$START_UTC $START_MS $START_DATE $END_DATE"
```

If Diego Ramirez gives a start date, use that date at 08:30 Pacific instead. When the computed start is today (a Thursday
after 08:30), the window is only a few hours long. State that in the reply.

## Step 2: GitHub (`gh`), the whole `iDerive-com` org

```bash
gh search prs --owner iDerive-com --author @me --updated ">=$START_UTC" --limit 200 \
  --json repository,number,title,state,isDraft,createdAt,closedAt,url \
  --jq '.[] | "\(.repository.nameWithOwner)\t#\(.number)\t\(.state)\tcreated=\(.createdAt)\tclosed=\(.closedAt)\t\(.title)"' | sort
```

- Keep a PR if it was created, merged or closed in the window, or if it is still open and was updated in the window.
- For each PR in `datasource_pipelines`, get its base branch, merge time and CI result:
  `gh pr view <n> --json baseRefName,headRefName,mergedAt,statusCheckRollup`.
  - Report CI only for open PRs. A merged PR can still show a stray `PENDING` check.
  - A PR whose base is another feature branch is a stacked PR. Group it with its ticket.
  - A PR into `main` is a release PR. Its body lists the dev PRs it ships, which tells you which tickets reached prod.
    The release also ships other people's tickets. Name those only in the release PR's ticket cell. They are not
    rows in "Tickets worked on" unless Diego Ramirez is assigned to them.
- The ticket id is `ID-<n>` in the branch name or the title. A PR can name several tickets.
- Group the PRs by repository in the report.

## Step 3: ClickUp (MCP)

`clickup_filter_tasks` has **no "updated since" filter**. Use these parameters:

- `assignees=["100891986"]`
- `include_closed=true`
- `order_by="updated"`

Results are sorted newest first. Keep every task whose `date_updated` (epoch ms) is `>= $START_MS`. Fetch the next
page only while the last task on the current page is still inside the window.

- Fetch with `clickup_get_task` (the custom id `ID-<n>` works as `task_id`) every ticket that will get its own
  row in the report but is missing from this list. Subtasks are often unassigned. Record its status and assignees;
  an unassigned ticket with Diego Ramirez's open PR is a mismatch.
- `date_closed` is set only for status `Closed`; `completed` tasks have it null. To tell whether a task finished in
  the window, use its status together with `date_updated`.
- **Type** comes from the name and tags. A name starting with `PDI:` or a `pdi` tag makes it a **PDI**. A name
  starting with `BUG:` makes it a **Bug**. Anything else in the `Pipes` list is **Pipes**. Anything else in another
  list gets that list's name (for example Data Engineering, Prod Eng OKRs).
- A ticket that was only closed in the window, with no PR and no plan activity, goes on one "also closed" line.
- Link every ticket that has its own row as `[ID-<n>](<url>)`, using the `url` that ClickUp returns. Never build the
  link by hand. Ids that are only mentioned in passing, such as an "also closed" line or a list of planned tickets,
  may stay plain.

## Step 4: Local plans

```bash
cd "$PLANS" && find . -newermt "$START_UTC" -type f -name '*.md' -not -path './standup_report/*' \
  | sed 's|^\./||' | sort
```

(`find` here is `bfs`, which accepts only ISO timestamps such as `2026-10-08T15:30:00Z`.)

The command lists only `.md` files. Every plan is one `<TICKET>_<slug>.md`, so each line is one ticket. A plan can
sit inside another ticket's directory; for example, `wip/ID-26499/ID-24565_*.md` is the plan for ID-24565. Files
directly in `plans/`, such as `TODO_NOW.md`, are snapshots, not tickets.

For each plan in that list, read its newest status section and nothing else. The heading starts with `## Status`
and may carry a date or subtitle. Some plans use a `Status:` line instead. In `HOTFIX_<date>/` directories, read
`TODO for …` or `What is left`. A hotfix covers several tickets: read its main file for the ticket list and for any
unticked closing steps.

Reconcile each plan's state directory with its ClickUp status:

| Plan state | Expected ClickUp status |
| --- | --- |
| `todo/` | any status before work starts |
| `wip/`, work going on | `in progress - nectar` |
| `wip/`, PR into `dev` open with CI green, or merged with deploy or verify steps open | `under review - nectar` or `deploying` |
| `done/` | `completed` or `Closed` |

A mismatch is any of these:

- the plan state and the ClickUp status disagree;
- a ticket is closed while its plan or hotfix directory is still in `wip/`;
- a ticket has an open PR but no assignee;
- a plan's own status header contradicts ClickUp;
- `plans/TODO_NOW.md` lists items that are now done.

## Step 5: Write the report

Save it to `$PLANS/standup_report/report_${START_DATE}_${END_DATE}.md` (create the directory if it is missing).
If that file already exists, ask Diego Ramirez whether to overwrite it. He may have edited it. `plans/` is gitignored, so
never stage the report.

Each ticket goes in exactly one of these sections. Take the first rule that matches:

1. **Finished**: the ticket is `completed` or `Closed` and changed in the window.
2. **Shipped or in review**: it has a PR in the window, and something is still open (review, deploy, verify, data
   fix, or a wait on someone else).
3. **In progress or planned**: everything else that had ClickUp or plan activity.

The report has these sections, in this order:

1. **Title and window:** `# Stand-up report: <start> → <end>`, the window in Pacific time and UTC, and the three
   sources.
2. **`## Summary for the project manager`:** five bullets in plain language, with ticket ids but no PR numbers
   and no file paths. Each bullet is at most two lines and names only the work that matters to the project
   manager. Closes without new work stay out of it.
   - **Shipped to prod**;
   - **Closed**;
   - **In review** (ships in the next release);
   - **Next**;
   - **Blocked on others**, naming who it waits on.
3. **`## GitHub`:** one table per repository with the columns `PR | State | Ticket`. The PR cell is a link plus a
   short title, and release PRs are in bold. Then one line naming the repositories with no PRs.
4. **`## Tickets worked on`:** three subsections:
   - `### Finished`
   - `### Shipped or in review (post-deploy steps still open)`
   - `### In progress or planned (no PR yet)`

   The first two are tables with the columns `Ticket | Type | PRs | What it was` (or `Status` instead of
   `What it was`). Each explanation is one or two lines: what was broken or built, and where it stands.
5. **`## Where plans and ClickUp disagree`:** a numbered list. Each item names the ticket, what each side says,
   and the fix.

## Step 6: Reply

1. Give the path of the saved report.
2. Repeat the project-manager summary in the chat.
3. Give the count of mismatches.
4. Ask whether to apply the ClickUp status changes and plan moves. Make them only after Diego Ramirez says yes.

## Example (shortened from the 2026-10-08 → 2026-10-14 report)

```markdown
# Stand-up report: 2026-10-08 → 2026-10-14

Window: Thu 2026-10-08 08:30 PT (15:30 UTC, PDT) → Wed 2026-10-14 11:00 UTC.
Sources: GitHub (`iDerive-com`, PRs authored), ClickUp (tasks assigned and updated in the window), `plans/`.

## Summary for the project manager

- **Shipped to prod (releases 10-08 and 10-13):** concurrent loads no longer overwrite each other's staging
  tables (ID-28213); workers stop before Lambda kills them (ID-28220); run logs are no longer lost (ID-28228); SQP
  fixes for expired seller authorizations (ID-23551) and vendor-account mappings (ID-25830).
- **Closed:** PDIs ID-28131 (AmazonAds checks failing for ~29 clients) and ID-25009 (balsam); ID-26890; ID-21241.
- **In review:** Batch Service stops calling Amazon once a job is fatal; schedule config cleanup (ID-26357); Runs
  admin filters (ID-24565); CodeRabbit follow-ups (ID-28226).
- **Next:** Runs admin speed (ID-28359), Pushover monitors (ID-28364), migrator hardening (ID-28365).
- **Blocked on others:** SQP re-authorizations for Rocky Brands, Maev, Beacon and TYR (Otto, account managers).

## GitHub: 13 PRs, all in `iDerive-com/datasource_pipelines`

| PR | State | Ticket |
|---|---|---|
| [#1095](https://github.com/iDerive-com/datasource_pipelines/pull/1095) LOAD staging isolation | merged 10-08 | ID-28213 |
| [#1106](https://github.com/iDerive-com/datasource_pipelines/pull/1106) **Release 20261013** | merged 10-13 | ID-21241, ID-23551, ID-28220, ID-25830, ID-28228 |
| [#1109](https://github.com/iDerive-com/datasource_pipelines/pull/1109) Runs grid uses the table's filters | **open**, CI green | ID-24565 |

## Tickets worked on

### Finished

| Ticket | Type | PRs | What it was |
|---|---|---|---|
| [ID-28213](https://app.clickup.com/t/86bceebk6) Concurrent LOAD workers share `_tmp` | Pipes | #1095, #1096 | Each LOAD session now has its own staging table, plus a row-count guard. Shipped 10-08; closed 10-09. |
| [ID-28131](https://app.clickup.com/t/86bcczuyv) PDI: AmazonAds models | **PDI** | none | `pipes_migrator_dag` schema drift broke `check_pipeline_status`. Completed 10-09; hardening split out into ID-28365. |

Also closed on 10-09 without new work: ID-28128, ID-26437, ID-24538, ID-22543, ID-22133, ID-22544, ID-22562.

### Shipped or in review (post-deploy steps still open)

| Ticket | Type | PRs | Status |
|---|---|---|---|
| [ID-23551](https://app.clickup.com/t/86bapjgyh) PDI: SQP ASIN missing fresh data | **PDI** | #1098, #1107 | #1098 is in prod; #1107 is on `dev`, not deployed. Waiting on seller re-authorizations. |

### In progress or planned (no PR yet)

- [ID-28359](https://app.clickup.com/t/86bchqj0j) Runs admin speed: in progress, next after ID-24565.

## Where plans and ClickUp disagree

1. **ID-26357**: the PR is merged, but ClickUp still says `in progress - nectar`. It should be `under review - nectar`.
2. **HOTFIX_20261002** is still in `wip/` although both of its tickets are closed; closing steps 1 and 3 are unticked.
```

## Common mistakes

| Mistake | Fix |
| --- | --- |
| The window starts on a fixed weekday at midnight UTC | Use Thursday 08:30 `America/Los_Angeles`, computed as in Step 1. |
| Only `datasource_pipelines` is searched | Use `gh search prs --owner iDerive-com`. |
| `clickup_filter_tasks` is called with a made-up `date_updated_gt` | That filter doesn't exist. Order by `updated` and cut off at `$START_MS`. |
| PRs are listed without their tickets, or tickets without their PRs | Every ticket row lists its PRs, including stacked PRs and the release PRs that shipped it. |
| PDIs are not separated from Pipes work | Every ticket row has a Type column. |
| The report only appears in the chat | Save it to `plans/standup_report/report_<start>_<end>.md`. |
| Statuses are fixed or plans moved during the report | Report the mismatches, and change things only after Diego Ramirez says yes. |
