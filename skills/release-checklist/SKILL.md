---
name: release-checklist
description: Use when Diego Ramirez asks for a Pipes release file or release checklist, the to-dos before merge, after merge, before deploy or after deploy of a release PR into main, says a release PR is merged or deployed, asks to run or resume the pre-flight or post-deploy checks of a release, asks to do the pending plan tasks of the tickets a release ships, or asks what's left in a release plan.
---

# Release checklist

Creates the tracking file for one Pipes release PR into `main` and runs its phases: before the merge, after the merge
and before the deploy, the deploy, and after the deploy. Opening the release PR is `create-release-pr`; run that
first.

The main job: every ticket the release ships has open tasks in its plan that wait on this release (scripts to run
before or after the deploy, data steps and backfills, prod checks, cleanup). The release file collects all of them,
puts each in the phase where it has to run, runs them, ticks them in both files, and closes each ticket once nothing
is left. The generic release checks (CI, pre-flight, host health, Lambdas) sit around them.

Not collected: plan tasks that don't depend on this release (a later phase of the ticket, unrelated ideas), and
problems found along the way that aren't a shipped ticket's work. Those go into the right ticket's plan or a new
ticket, with one pointer line here.

## Ground rules

- **Read-only unless Diego says go.** Reads: `nectar-db-reader` (`prod-pipes`, `prod-batch-service`, …), `tsh ssh`,
  the AWS CLI (two or three calls at a time, never a burst), Playwright on the admin. Never `psql`, `.env` or `.env.db`;
  on a host, drop lines matching `SecretString|PASSWORD|SECRET` before printing.
- **Merging and deploying** are Diego's. The agent deploys only when Diego explicitly says to deploy, and only after
  the pre-flight below.
- **Hosts:** `tsh ssh ec2-user@pipes-prod` (checkout `/var/datasource_pipelines`, cron logs
  `/var/log/iderive/cron_logs/`, Python `.venv/bin/python`) and `tsh ssh ubuntu@batch-service`. If `tsh` has expired,
  stop and ask Diego to log in; never plain `ssh`.
- **Lambdas:** the prod stacks are `pipes-stack` and `pipes-stack-large`. Find the function names with
  `aws cloudformation describe-stack-resources --stack-name <stack> --query "StackResources[?ResourceType=='AWS::Lambda::Function'].PhysicalResourceId"`,
  then `aws lambda get-function-configuration --function-name <name> --query '[State,LastUpdateStatus,LastModified,Environment.Variables.DEBUG_MODE]'`.
- **Report only what fails or needs Diego.** A harmless quirk that predates the release stays out of the file.

## Step 1: Gather the facts

Release PR `<pr>` (from `gh pr list --base main --state open` if not given). In `~/Developer/repos/pipes/datasource_pipelines`:

1. `git fetch origin`, then `gh pr view <pr> --json number,title,headRefName,baseRefName,state,mergeable,statusCheckRollup,reviewDecision,autoMergeRequest,body,files`.
2. What prod runs now: `tsh ssh ec2-user@pipes-prod 'git -C /var/datasource_pipelines rev-parse --short HEAD'`, and the
   Alembic head through `nectar-db-reader` (`select version_num from alembic_version` on `prod-pipes`, and on
   `prod-batch-service` when `batch_service/` changes).
3. What the release adds: `git diff --stat <prod sha>..origin/<release branch>` and `git log --oneline` over the same
   range. Sort the changed files:

   | Changed | Means |
   | --- | --- |
   | `migrations/versions/` | Alembic step in the deploy; estimate its duration (table sizes via `nectar-db-reader`) |
   | `connectors/`, `lambda_handler*`, `reports_config*`, root `Dockerfile`, a module the Lambda imports | `--deploy-lambda` |
   | `django/` | uwsgi restart (always part of `deploy_server.sh`) |
   | `batch_service/` | Batch Service deploy, `deploy_batch_service.sh` |
   | `pyproject.toml`, `uv.lock` | dependency change |
   | `.env.shared*`, new `config.` keys | config change; a host `.env` override may shadow it |
   | crontab, `scripts/` run by cron | cron change, live after the deploy restarts crond |
   | `terraform/` | not deployed by the release; an apply is a separate step for the AWS admin |

4. **The tickets' open tasks.** For each dev PR in the release:
   - Its ticket (`ID-<n>` from the PR title or body; `clickup_get_task` for status and owner) and its plan
     (`find ~/Developer/repos/pipes/plans -maxdepth 2 -name 'ID-<n>*'`; in a three-file directory, `_plan.md` and its
     `## Status`).
   - Read the whole plan and list every open item (`- [ ]`, the Status section's "Left", any "after the deploy",
     "post-release", "on prod" or runbook step). Keep the ones that wait on this release; for each, note its phase
     (before the merge, before the deploy, during the deploy, right after, later on a date), who does it, whether it
     writes anything, and its plan section.
   - A ticket without a local plan (a teammate's): take its post-deploy checks from the PR body and the ClickUp
     description, and mark them as the owner's.
   - A plan item that is unclear or stale: ask Diego rather than guess.

## Step 2: Create the file

`~/Developer/repos/pipes/plans/wip/RELEASE_<pr>_<YYYYMMDD>/RELEASE_<pr>_<YYYYMMDD>.md`. Artifacts (baselines, query
outputs, schedule id lists, backfill results) go in the same directory, prefixed `RELEASE_<pr>_`. If the file exists,
update it instead.

```markdown
# Release #<pr> (<YYYYMMDD>): deploy and post-release steps

**Release PR:** [#<pr>](<url>), `release/<date>` into `main` (<full | subset> of `dev` @ `<sha>` onto `main` @
`<sha>`, <n> files). CI: <state>. Approval: <state>. Auto-merge: <on/off>.

| dev PR | What | Ticket | ClickUp | Plan |
| --- | --- | --- | --- | --- |
| #<n> | <one line> | [ID-<n>](<url>) (<owner>) | `<status>` | `plans/<state>/…` or none |

**Prod before this release:** `main` `<sha>` (release #<prev>, deployed <date>). Alembic `<rev>`.

**What the release adds:** one bullet each for migrations (revision, what it does, expected duration), Django,
Lambda, Batch Service (or "no Batch Service deploy"), dependencies, config keys.

**Order that matters:** only when it applies (e.g. the fix is live only after the Lambda deploy; a data step that
must wait for the deploy).

**Ticket tasks:** every open task the shipped tickets' plans hold for this release. Each one also appears as a line
in its phase below, prefixed with its ticket.

| Ticket | Plan | Tasks for this release | Writes? | Ticket done when |
| --- | --- | --- | --- | --- |
| [ID-<n>](<url>) | `plans/wip/ID-<n>/ID-<n>_plan.md` §<section> | <short list, by phase> | <no / what it writes> | <its last task ticked> |

## Status

Updated <YYYY-MM-DD HH:MM UTC>. <phase and next action>

### Log

- <YYYY-MM-DD>: release file created.

## Before the merge

- [ ] CI of #<pr> green (all required checks, `Require Release Branch For Main` included).
- [ ] Approval.
- [ ] CodeRabbit on #<pr>: findings collected and triaged, follow-up ticket [ID-<n>](<url>) opened with all of them,
      every thread answered and resolved (see "CodeRabbit review of the release PR").
- [ ] Release PR link posted on every ticket it ships (`Here is the link to the PR into main (prod release):`, the
      full URL as text; skip tickets that already have it; `ENG-*` reported as not posted).
- [ ] <decisions Diego has to take before merging, one line each>
- [ ] <ID-<n>: each ticket task due before the merge, with its plan section>

## After the merge, before the deploy (agent, read-only)

- [ ] pipes-prod pre-flight: checkout clean (`git status`), no deploy running
      (`ps -eo pid,etime,cmd | grep "[d]eploy_server"`), uwsgi and crond `active`, Alembic `<current rev>`.
- [ ] `tsh ssh ec2-user@pipes-prod 'sudo bash -s' < scripts/check_host_health.sh`: `RESULT:` line.
- [ ] Prod Lambdas (regular and `-large`): `Active` / `Successful`, `DEBUG_MODE=false`.
- [ ] <migration duration estimate, when there is a migration>
- [ ] <baselines the post-deploy checks compare against: counts, run statuses, rows per account>
- [ ] <Batch Service pre-flight on `tsh ssh ubuntu@batch-service`, when it deploys>
- [ ] <ID-<n>: each ticket task due before the deploy (pre-deploy scripts, baselines, dry runs)>

## Deploy (Diego)

- [ ] Merge #<pr> (merge commit `<sha>`).
- [ ] `./scripts/deploy_server.sh --env prod[ --deploy-lambda]` on pipes-prod.
- [ ] <`./scripts/deploy_batch_service.sh --env prod --dry-run`, then without `--dry-run`, when it deploys>
- [ ] Times in the deploy log.

## Right after the deploy (agent, read-only)

- [ ] Host: checkout on the merge commit, `git status` clean, uwsgi and crond `active`, no new error lines in
      `/var/log/uwsgi/uwsgi.log`, `alembic current` `<new rev> (head)`.
- [ ] `check_host_health.sh` on pipes-prod: `RESULT:` line.
- [ ] Both Lambdas updated (last-modified after the deploy), `Active` / `Successful`, `DEBUG_MODE=false`.
- [ ] <one check per dev PR that proves its change works on prod: admin pages through Playwright, the first runs of
      the touched connectors and their `run_logs`, a query against the baseline>
- [ ] <Batch Service: `batch_service` unit active, `/health` returns 200, `sudo journalctl -u batch_service` clean
      since the restart, `alembic_version` on `prod-batch-service` at the new head>
- [ ] <ID-<n>: each ticket task due right after the deploy (post-deploy scripts, backfills, prod checks)>

## Deploy log

- [ ] Merged as `<sha>` at <time>.
- [ ] Alembic step: <start-end>, <duration>.
- [ ] Lambdas: regular <time>, `-large` <time>.
- [ ] Deploy end <time>.

## After the deploy, by date (UTC)

| When | What | Who | Where |
| --- | --- | --- | --- |
| <deploy day 22:00, next daily run, …> | <check> | <agent read-only / Diego / owner> | <this file / ID-<n>> |
| <date> | <ID-<n>: a ticket task due later> | <who> | <plan section> |
```

Fill every `<…>`. Drop a bullet that doesn't apply instead of writing "n/a". Each check says what passing looks
like, so it can be ticked without judgement.

## CodeRabbit review of the release PR

Run this as soon as CodeRabbit has reviewed the release PR.

1. **Collect** every finding: the inline threads (`gh api repos/iDerive-com/datasource_pipelines/pulls/<pr>/comments`,
   top-level comments only), and the outside-diff items and nitpicks in the review body
   (`gh api repos/iDerive-com/datasource_pipelines/pulls/<pr>/reviews`).
2. **Triage** each one against the code on the release branch: relevant (a real bug or a doc/name that is wrong, to
   fix in a PR into `dev`) or discarded (can't happen in Pipes, or churn), with a one-line reason. Note the dev PR it
   came from.
3. **Open one follow-up ticket** in the Pipes list (`901417632447`), assigned to Diego, named
   `Release #<pr> CodeRabbit follow-ups`. The description holds every finding, discarded ones included for reference:
   a "To do" section (numbered; file and line, the problem, the fix, the thread link, the shipped ticket it came from)
   and a "Declined (for reference)" section (each with its thread link, or "review body", and the reason). Link it
   "related" to the shipped tickets the findings came from (`clickup_add_task_link`). Save the ticket text as
   `plans/todo/ID-<n>/ID-<n>_ticket.md`, and add its link to this file's "Before the merge" item.
4. **Answer and resolve every inline thread**: reply in the thread (`pulls/comments/<id>/replies`, never a top-level
   PR comment), tag `@coderabbitai`, and link the ticket, e.g. "@coderabbitai This will be handled in the follow-up
   ticket [ID-<n>](<url>)." For a discarded finding, add that it is declined there and the one-line reason. Then
   resolve the thread (GraphQL `resolveReviewThread`). Review-body items have no thread: they are only in the ticket.

## Step 3: Run a phase

When Diego says the PR is merged, the deploy is done, or asks to run or resume a phase: run all of that phase's items,
the generic checks and the ticket tasks, in the order the file lists them.

- **Read-only items:** run them and tick each with its evidence inline (time, SHA, count, `RESULT:` line).
- **Items that write** (a backfill, a data fix, a script with `--apply`, a host change, a ClickUp change): show
  Diego the exact command or action and its dry-run output, and run it only on his go. When the plan says Diego runs
  it himself, give him the command and verify the result afterwards.
- **Ticket tasks:** tick them in the ticket's plan too, with the same evidence, and update that plan's `## Status`.
  The two files must agree.
- After each phase, update this file's `## Status` and `### Log`.

On a failure, stop the phase and tell Diego what failed and what it affects. Don't fix things on the host.

The deploy itself, when Diego asks the agent to do it: re-run the pre-flight `ps` check as its own command first, then
deploy, and record the step times in the deploy log.

## Step 4: Close

**Each ticket, as soon as its last task is ticked** (not only at the end of the release):

- Diego's ticket with nothing else open in its plan: move its plan to `plans/done/` (fix paths pointing at it) and
  set ClickUp `completed` if it isn't already. Report it in the reply.
- Diego's ticket with work left that doesn't depend on this release: it stays in `wip/`; say what is left.
- A ticket someone else owns: change nothing in ClickUp. If its post-deploy checks passed, tell Diego, who can tell the
  owner.

**The release**, when every item is ticked or dropped (with Diego's reason): write the closing Status line, with
each ticket's outcome, and move the directory to `plans/done/`.

## Common mistakes

| Mistake | Instead |
| --- | --- |
| Listing PRs merged into `dev` after the release, or "next release" items | Only this release's PRs. |
| Building the checklist from the PR diff only | Read every shipped ticket's plan; its open release tasks are the main content. |
| Ticking a ticket task here but not in its plan | Tick both, same evidence. |
| Leaving a finished ticket in `wip/` until the release closes | Close it as soon as its last task is ticked. |
| Pulling in plan tasks that don't wait on this release | Leave them in the plan. |
| Logging a new problem found along the way as a release item | One pointer line; the work goes in a ticket's plan or a new ticket. |
| Listing CodeRabbit's findings in this file and stopping there | Collect, triage, open the follow-up ticket with all of them, answer and resolve every thread. |
| Checking the host by hand instead of `check_host_health.sh` | Run the script and record its `RESULT:` line, plus the deploy-specific checks. |
| Taking prod's SHA from `origin/main` | Read it on the host. |
| Forgetting the `-large` Lambda | Both functions, every time. |
| Ticking a check without its evidence | Tick it with the evidence, inline. |
| Reading prod data with `psql` or `.env.db` | `nectar-db-reader` only. |
