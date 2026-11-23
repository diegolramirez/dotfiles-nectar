---
name: review-teammate-pr
description: Use when Diego Ramirez asks to review someone else's pull request, a teammate's PR or a PR where his review is requested, to check a PR against a ticket or its plan, to say whether a PR is ready to merge, or to draft or post review comments or a "request changes" review on a PR he did not write, or to self-review his own PR before asking for review.
---

# Review a teammate's PR

Read the PR against what the ticket wants, give Diego a verdict, draft the review in a colleague's voice, and post
only after his go. The author usually never saw Diego's local plan, only the ClickUp description and comments, so the
plan is Diego's intent, not a spec the author failed.

`<n>` is the PR number, `<repo>` is `owner/name` (`gh repo view --json nameWithOwner -q .nameWithOwner`).

## Step 0 — Preconditions

```bash
git ls-remote --exit-code origin >/dev/null 2>&1 && echo "git auth:      ok" || echo "git auth:      FAILED"
command -v gh >/dev/null 2>&1                    && echo "gh installed:  ok" || echo "gh installed:  MISSING"
gh auth status >/dev/null 2>&1                   && echo "gh auth:       ok" || echo "gh auth:       FAILED"
```

**If any check fails, stop and report it.** Do not run `gh auth login`, install `gh`, or touch credentials, SSH keys
or remotes. Name the failed check and what Diego needs to do, then end the turn.

## Step 1 — Find the PR

1. **Diego named one** (number or URL): use it.
2. **Otherwise list the open PRs that request his review** and ask which one:
   ```bash
   gh pr list -R <repo> --search "review-requested:@me" --json number,title,author,headRefName \
     --jq '.[] | "#\(.number)\t\(.author.login)\t\(.headRefName)\t\(.title)"'
   ```

Then check it:

```bash
gh pr view <n> -R <repo> --json number,url,state,isDraft,author,headRefName,baseRefName,mergeStateStatus,reviewDecision,statusCheckRollup
```

- `state` not `OPEN` → stop; never comment on a closed or merged PR.
- `isDraft: true` → review it, but the event in Step 4 is `COMMENT`, never `REQUEST_CHANGES`.
- Author is Diego:
  - Asked to answer or fix review comments on it → wrong skill, use `address-pr-review`.
  - Asked to review it → **self-review mode**: run Steps 2-4, but Step 4 returns a to-do list for him (kind,
    `path:line`, what to change) instead of review drafts, and Step 5 is skipped. GitHub allows only `COMMENT` on
    your own PR; post one only if he asks.
- Read the code from `origin` (`git fetch origin`, `git diff origin/<base>...origin/<head>`, `git show origin/<head>:<path>`).
  Never check out, commit to or push the author's branch.

## Step 2 — Gather the intent and what was already said

- **Ticket:** the id from the branch or title. Read the ClickUp description **and its comments**: decisions made
  after the description was written live in the comments, and the author may only have seen the description.
- **Links in the ticket** (specs, docs, artifacts): open them. A claude.ai artifact is read with the Artifact tool's
  `read` action.
- **Plan (pipes):** `find ~/Developer/repos/pipes/plans -name '<TICKET>*'`. Read the Problem, Decisions, Scope and
  Global Constraints, not only the task list.
- **No readable intent** (no plan, a thin description, a spec link that doesn't load, an empty PR body): say so in
  the report to Diego, name what you couldn't read, and review the code on its own terms. Don't guess the intent.
- **Existing review**, so you don't repeat a point someone already made:
  ```bash
  gh api --paginate repos/<repo>/pulls/<n>/comments --jq '.[] | "\(.user.login) \(.path):\(.line) \(.body[0:150])"'
  gh api --paginate repos/<repo>/pulls/<n>/reviews  --jq '.[] | select(.body != "") | "\(.user.login) \(.state) \(.body[0:300])"'
  gh api --paginate repos/<repo>/issues/<n>/comments --jq '.[] | "\(.user.login) \(.body[0:200])"'
  ```

## Step 3 — Review

**Large PR** (more than ~1,000 changed lines or several areas, such as schema, connectors and Django): split the
review by area, one fresh `opus` subagent per area, in parallel, each briefed with `reviewer-prompt.md` (in this
skill's directory). Merge and verify their main points yourself in the code before reporting; drop any you can't
confirm.

**Failing checks:** read the root error of the first failing job
(`gh run view <run id> -R <repo> --log-failed`, grep for `Error`). One cause often explains several jobs; it's a Bug
point when the PR causes it.

Check correctness first, by reading code, not the PR description: run read-only checks that prove a claim (compare
lists, `bash -n`, grep the callers). Then compare with the intent and the repo's `CLAUDE.md` rules. Sort every point
into one kind; the kind decides the wording in Step 4:

| Kind | When | Wording |
| --- | --- | --- |
| Bug | Wrong behavior, broken deploy, security | State it plainly with the failing case |
| Suggestion | Something the plan has that the PR doesn't | "How about …?" + why it helps + a snippet |
| Question | The PR does it differently from the plan or ticket | Describe both, ask why and what they think |
| Removal | Code that shouldn't be there | Ask to drop it **and give the reason** (the rule behind it) |
| Nit | Style, wording, ticket ids in comments | "Nit: maybe …?" |

**Leave out of the review** (mention to Diego only if it matters): the branch being behind the base, the author's
commit trailers, verification steps the deploy will cover anyway, plan or ClickUp housekeeping, and anything Diego
said he will handle. **Exception:** something the stale base actually breaks (two Alembic heads, a conflict
that changes behavior, a removed function the PR still calls) is a Bug point; name the rebase only as its fix.

## Step 4 — Report to Diego and draft

In the terminal: the verdict (ready to merge or not, in one line), what's right, then the points by kind. Then the
drafts.

**What goes into the drafts:** Bugs, Questions, Removals, and Suggestions that change behavior. Nits and the
remaining small suggestions go in a "Left out of the drafts" list in the terminal, one line each; Diego picks any to
add. Group related points (several tests broken by the same rule) into one comment that names the other lines.

The drafts:

- **Review body:** one line on what looks good, then numbered points. Each point: what, why, and the suggestion or
  question. Short sentences, plain words, no stock phrases.
- **Inline comments:** `path:line` (a line on the head side of the diff; a range uses `start_line`), one or two
  sentences each, softened ("Nit:", "Small thought:", "I think … maybe …?").
- **Event:** on a draft, always `COMMENT`. Otherwise `REQUEST_CHANGES` when a bug, removal or suggestion should land
  before merge, and `COMMENT` when it's only questions and nits. `APPROVE` only when Diego says so.

**Wait for his go.** He will usually reword; apply his edits and show the result again if they're more than small.

## Step 5 — Post

One review with all inline comments, never a string of top-level comments:

```bash
jq -n --arg sha "$(gh pr view <n> -R <repo> --json headRefOid -q .headRefOid)" --rawfile body body.md '{
  commit_id: $sha, event: "REQUEST_CHANGES", body: $body,
  comments: [
    {path: "scripts_runner.sh", line: 153, side: "RIGHT", body: "Nit: …"},
    {path: ".gitignore", start_line: 59, line: 61, start_side: "RIGHT", side: "RIGHT", body: "…"}
  ]}' > review.json
gh api -X POST repos/<repo>/pulls/<n>/reviews --input review.json --jq '{state, html_url}'
```

Write `body.md` and `review.json` in the session scratchpad. Report the review link.

## Red flags

- A precondition failed and you are fixing it → stop and report.
- Posting, or changing the drafts' meaning, before Diego's go → stop.
- Calling something "missing" because it's in the plan → it's a suggestion; the author didn't have the plan.
- Asking to remove something without saying why → add the rule behind it.
- About to approve or merge, push to the author's branch, or comment on ClickUp → only if Diego asks.
