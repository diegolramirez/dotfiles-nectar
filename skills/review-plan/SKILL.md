---
name: review-plan
description: Use when Diego Ramirez asks to review a plan before handing it off, whether a plan file is fully ready, standalone or self-contained, whether a new or fresh agent could execute it without this conversation, whether it achieves the design doc, or asks for the prompt to start a fresh agent on a plan.
---

# Review plan

Checks with a fresh agent that a plan can be executed by a brand-new agent, fixes what it finds (at most three review
rounds), then gives Diego the prompt that starts the execution.

## Step 1: Gather the paths

Find the plan, its design doc and its ticket file. For a ticket that is
`find ~/Developer/repos/pipes/plans -maxdepth 2 -name 'ID-<n>*'`. An older single-file ticket has the plan, design and
ticket in one file. Note which worktree and branch the plan uses, if any already exist.

## Step 2: Review with a fresh Fable agent

Start a **new** agent for every round: `Agent` with `model: "fable"`, `subagent_type: "general-purpose"`. Never
continue a previous reviewer with SendMessage: it has seen the earlier version.

Brief it with the paths only, not your opinion of the plan:

```text
You are about to judge whether an implementation plan can be executed by a brand-new agent that has no access to
the conversation in which it was written. Read these in full: <plan path>, <design doc path>, <ticket file path>,
<repo>/CLAUDE.md and ~/Developer/repos/pipes/CLAUDE.md. Check the code the plan names against origin/dev in
<repo path> (run `git fetch origin` first; read only, change nothing).

Answer three questions:
1. Is the plan complete and standalone: could you start Task 0 and finish the last task without asking anyone?
2. Does it give enough context and rules (goal, constraints, type annotations, what tests to write, commands to run)?
3. Does it achieve what the design doc asks for, all of it and nothing beyond it?

Reply in this shape:
VERDICT: READY or NOT READY
GAPS: a numbered list. Each gap names the plan section, what an executor would have to guess or would get wrong,
and the fix. List only gaps that would make an executor stop, guess, or build something the design doc does not
ask for. An empty list means READY.
```

## Step 3: Fix and repeat (at most three rounds)

- **READY:** go to Step 4.
- **NOT READY:** check each gap against the code and the design doc before acting on it. Fix the real ones in the
  plan file; reject a wrong one and note why. When a gap needs a decision that isn't in the design doc, ask Diego
  (one question at a time, with your recommendation) instead of inventing it, and log his answer in the design doc's
  `## Decisions`. Then run Step 2 again with a new agent.
- **Still NOT READY after the third review:** don't write the prompt. Show Diego the remaining gaps and what you
  tried.

Add one line to the `### Log` under the plan's `## Status` for each round: date, verdict, gaps fixed, gaps rejected
with the reason.

## Step 4: The execution prompt

Give Diego the prompt in one `text` code block he can paste into a new session. It has these parts, in this order,
and nothing else. Leave the plan's content out of it: the agent reads the plan.

```text
Execute the implementation plan for ClickUp ticket ID-<n> (<ticket url>).

Plan: <absolute path to the plan>
Design: <absolute path>    Ticket: <absolute path>

Read in full before starting: <repo>/CLAUDE.md, ~/Developer/repos/pipes/CLAUDE.md, the plan, then the design doc.
Start at <Task 0 | the first unchecked task: Task k>. <Worktree: <path> on branch <name>, already created. | Task 0 creates the worktree.>
Run it with superpowers:subagent-driven-development, with the plan's Global Constraints over the skill's defaults: workspace in <ticket dir>/ID-<n>_sdd/, a fresh agent for every implementer and fix round (models from ~/Developer/repos/pipes/CLAUDE.md), and no finishing-a-development-branch (the plan's final task opens the PR).
After each task, update ## Status at the top of the plan (what is done with its commit SHA, what is next) and add a line to its ### Log.
Stop and ask me before <the steps the plan marks as needing my go, plus any deploy or prod write>.
<Extra facts the plan can't hold, one line each, only when they exist: another agent working on a branch, a PR that must merge first, a time constraint.>
```

Below the block, write two lines: how many review rounds ran and what changed in the plan; and where to start the
new session: in `~/Developer/repos/pipes/` or in the worktree, never in `datasource_pipelines/`, where a `cd` to the
sibling worktree resets and the agent ends up working on `dev`.

## Common mistakes

| Mistake | Instead |
| --- | --- |
| Reviewing the plan yourself instead of a fresh agent | The writer can't see the gaps; always a new Fable agent. |
| Telling the reviewer "I think it's ready, confirm" | Paths and questions only. |
| Reusing the reviewer for round two | A new agent each round. |
| Inventing an answer to a gap that needs a decision | Ask Diego, log it in the design doc. |
| A fourth round, or a prompt after a third NOT READY | Stop at three and report the gaps. |
| Restating the plan inside the prompt | The prompt points at the files. |
| Relative paths in the prompt | Absolute paths; the new session may start in another directory. |
