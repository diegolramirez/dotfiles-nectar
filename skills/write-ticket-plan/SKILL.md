---
name: write-ticket-plan
description: Use when Diego Ramirez says the design or specs for a Pipes ticket are done and it is time to write the implementation plan, or asks to write, rewrite or start the plan for a ticket from its design doc.
---

# Write the ticket plan

Writes the implementation plan for a ticket whose design doc is agreed, so that a fresh agent with no access to this
conversation can do all the changes. It ends when the plan is written. Checking it and writing the execution prompt
is the next skill, `review-plan`.

## Step 1: Find the files

```bash
find ~/Developer/repos/pipes/plans -maxdepth 2 -name 'ID-<n>*'
```

- **Three-file directory:** the plan goes in `ID-<n>_plan.md`. Read `ID-<n>_ticket.md` and `ID-<n>_design.md` in full
  first.
- **Older single-file ticket:** the plan goes at the end of that file as `## Implementation Plan`, with its headings
  demoted one level.

If the design doc has open questions that change what gets built, ask Diego before writing.

## Step 2: Write it with superpowers:writing-plans

Use `superpowers:writing-plans`, with these overrides:

- **Location:** the file from Step 1, never `docs/superpowers/plans/`. `plans/` is gitignored: never commit or
  stage it.
- **Execution handoff:** skip the skill's closing offer to execute the plan. The next step is `review-plan`.

The plan file holds, in this order. Parts 3, 5 and 6 are the header `superpowers:writing-plans` requires, filled in
as described here:

1. **Title and links** to `ID-<n>_ticket.md` and `ID-<n>_design.md`.
2. **`## Status`**: move it here from the top of the design doc, with its `### Log` (leave a one-line pointer in the
   design doc), and add a log line: "<date>: plan written; next: review-plan".
3. **Header:** `**Goal:**` says what the change achieves and how to tell it is done, explicitly, in two to five
   sentences matching the design doc (this replaces the skill's one-line goal). Then `**Architecture:**`,
   `**Tech Stack:**` and `**Spec:**` with the absolute path of `ID-<n>_design.md`.
4. **`## Context`**: everything an agent without this conversation needs: the files and functions involved, why the
   current behaviour is wrong, the decisions from the design doc that constrain the code, and what is out of scope.
   Link the design doc for the reasoning; restate only what the tasks depend on.
5. **`## Global Constraints`**: the design's constraints plus at least these rules, written out in full.
   subagent-driven-development copies this section into every task brief, so this is how the rules reach the
   implementers and reviewers.
   - Every new function, and every existing function you modify, gets full Python type annotations (every
     parameter and the return). Don't annotate code you aren't otherwise changing.
   - Tests check our code's behaviour for the changes and features in this plan, meaningfully. No tests of
     constants, of the database or SQL engine, of Django or the ORM, or of libraries. Mock only external
     boundaries (DB connections, HTTP, S3, the clock).
   - No ticket ids in code comments, docstrings or migrations.
   - Commits carry no `Co-Authored-By` or other attribution trailer. Stage files by explicit path; never stage
     anything under `plans/`.
   - The subagent-driven-development workspace (ledger, briefs, reports) goes in
     `~/Developer/repos/pipes/plans/<state>/ID-<n>/ID-<n>_sdd/`, not `.superpowers/sdd/`.
   - Every sub-agent is a fresh `Agent` call with the model from the table in `~/Developer/repos/pipes/CLAUDE.md`.
     A fix round starts a new implementer with the reviewer's findings, instead of resuming the old one.
   - Read the repo `CLAUDE.md` and `~/Developer/repos/pipes/CLAUDE.md` in full before Task 1.
6. **`## Review Focus`**, as `superpowers:writing-plans` defines it.
7. **Task 0**: the setup task from `~/Developer/repos/pipes/CLAUDE.md`, filled in with this ticket's id, slug and
   base branch (`origin/dev`, or the parent branch when the design says the work stacks on another PR).
8. **Tasks 1..N**, as `superpowers:writing-plans` lays them out, each with the exact files, the tests to write first,
   and the commands to run (`uv run pytest …`, `uv run flake8 .`, `uv run pre-commit run --files …`). For a bug,
   Task 1 writes the test that reproduces it from the design doc's root cause and shows it failing; the fix comes
   after (phase 4 of `superpowers:systematic-debugging`). If the fix doesn't make it pass, the executor stops and
   reports instead of stacking more fixes.
9. **Final task**:
   - Run the checks before the PR (the full suites that apply, lint).
   - Open the PR with the `create-dev-pr` skill. Skip `superpowers:finishing-a-development-branch`: no local
     merge.
   - Then do the ClickUp steps `create-dev-pr` leaves out: post the PR-link comment, and once CI is green, set
     `under review - nectar`, both as `~/Developer/repos/pipes/CLAUDE.md` describes.
   - Add the deploy and verification steps the design calls for, marked as needing Diego's go.

## Step 3: Hand back

Tell Diego the plan's path, the number of tasks, and anything you had to assume. Suggest `review-plan` as the next
step. Don't start executing the plan.

## Common mistakes

| Mistake | Instead |
| --- | --- |
| Saving to `docs/superpowers/plans/` because writing-plans says so | The ticket's `_plan.md`. |
| Leaving the rules out because "they're in CLAUDE.md" | Write them into the plan: the executor reads the plan first. |
| Rules in a section named anything but `## Global Constraints` | That name is what reaches every task brief. |
| A goal that says what to change, not what it achieves | State the outcome and how to check it. |
| Context that says "as discussed" | Spell it out or link the design doc section. |
| Tests that assert a constant, a SQL result shape or a library call | Assert our functions' behaviour. |
| Offering to execute the plan right away | Hand back; `review-plan` is next. |
