---
name: wrap-up
description: Use when Diego Ramirez says to wrap up, stop for now or continue later, asks for a prompt or handoff prompt to resume later, asks what's left or what's next in a ticket, plan or release file, or asks to update or track the progress in the plan files.
---

# Wrap up

Brings the session's tracking file up to date from the live state, says what is left, and on a wrap-up gives the
prompt that resumes the work in a new session.

Two modes, chosen by what Diego asked:

- **Status:** "what's left?", "what's next?", "update the plan with the progress". Steps 1, 3, 4, then answer.
- **Wrap-up:** "let's wrap up", "stop for now", "give me a prompt to resume later". All steps.

## Step 1: Find the tracking files

The files this session worked from. Usually one, sometimes two (a ticket plan and a release file):

| Work | File | Status goes |
| --- | --- | --- |
| Ticket, three-file layout | `plans/<state>/ID-<n>/ID-<n>_plan.md` | `## Status` at the top; in `_design.md` until the plan exists |
| Ticket, older single file | its `<TICKET>_<slug>.md` | its existing status section |
| Release | `plans/<state>/RELEASE_<pr>_<date>.md` | its checklist and status section |
| Hotfix or other cross-ticket work | the directory's main file | its status section |

`plans/` is `~/Developer/repos/pipes/plans`. If the session touched several tickets and it is unclear which ones
to cover, ask.

## Step 2: Stop (wrap-up only)

Start nothing new. For each running background agent or command:

- **Read-only work** (exploration, tests, a review): note its output file path and what it had finished, then stop
  it with TaskStop.
- **An agent writing code** (an implementer editing or committing in a worktree): don't stop it mid-edit. Ask Diego
  whether to wait for it to finish; record it as "in flight" meanwhile.
- **Anything changing shared state** (a deploy, a migration, a backfill, a script writing to a database, a push):
  don't stop it. Tell Diego it is still running and record it as "in flight".

## Step 3: Check the live state

Take every fact from a command run now, not from memory of the conversation:

- In the worktree: the current branch, `git status --short`, and the unpushed commits:
  `git log --oneline origin/<branch>..HEAD`, or `origin/<base>..HEAD` (base `dev`, or the parent branch of a stacked
  PR) when the branch was never pushed.
- The PR, when there is one: `gh pr view <n> --json state,isDraft,mergeable,statusCheckRollup,reviewDecision`.
- The ClickUp status of each ticket covered (`clickup_get_task`).
- Results that only exist in this conversation (query outputs, decisions, things Diego says he did himself): these
  go into the file now, since the next session can't see them.

Don't commit, push, move plan files or change ClickUp here. Put each of these at the top of "Left", for Diego's go:

- uncommitted or unpushed work;
- a state move CLAUDE.md requires that hasn't happened: PR open and CI green → `under review - nectar`; merged to
  `dev` with nothing open → plan to `done/` and `completed`.

## Step 4: Update the file

Rewrite the `## Status` section to the current state. Keep every line of its `### Log` subsection (other skills
and the executing agent append there) and add one line. A file without a `### Log` gets one.

```markdown
## Status

Updated <YYYY-MM-DD HH:MM>.

- **Done:** <each item with its evidence: commit SHA, PR number, query result, check output>
- **In flight:** <running deploys, agents or reviews; "nothing" when there are none>
- **Left, in order:**
  1. <action> (<who: Diego or agent>)
  2. …
- **Waiting on:** <people, reviews, merges, with links; omit when empty>
- **Resume here:** <the single next action>

### Log

- <YYYY-MM-DD>: <one line: what this session did>
```

Also tick the `- [ ]` boxes of tasks that are done, and delete items the session showed to be stale or out of
scope. "Left" names concrete actions ("run the dry run of X on pipes-dev"), not topics ("testing").

## Step 5: Reply

**Status mode:** the "Left, in order" list and the "Resume here" line, plus anything Diego has to do himself. Nothing
more.

**Wrap-up mode:** the same list, then the resume prompt in one `text` code block, with these parts in this order:

```text
Resume <ticket ID-<n> (<url>) | release #<pr> | <work name>>: <one line on what the work is>.

Read first, in full: <repo>/CLAUDE.md, ~/Developer/repos/pipes/CLAUDE.md, then <status file, absolute path> from ## Status, then <other files the next steps need, absolute paths>.
Worktree: <path> on branch <name>. PR: <url> (<state>).   <omit what doesn't exist>
Before acting, check: <the one to three live facts the next step depends on, e.g. PR checks green, branch deployed on pipes-dev>.
Next steps:
1. <from "Left, in order">
2. …
<Only when it applies: one line per thing the next session must not do, with the reason, e.g. "Don't touch branch X: another agent works on it.">
```

The prompt points to the files instead of repeating them. Use absolute paths.

## Common mistakes

| Mistake | Instead |
| --- | --- |
| Writing the status from memory of the conversation | Step 3 commands first. |
| "Left: testing, docs" | Concrete actions, each with who does it. |
| Leaving done or dropped items in "Left" | Remove them. |
| Stopping a running deploy or backfill to wrap up | Leave it, record it as in flight. |
| Committing or pushing as part of the wrap-up | List it as left, unless Diego asked. |
| Pasting the plan's content into the resume prompt | Point at the files. |
| Answering "what's left" from the chat instead of the file | Update the file, then answer from it. |
