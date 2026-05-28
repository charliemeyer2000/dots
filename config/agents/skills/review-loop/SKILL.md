---
name: review-loop
description: Monitor a PR through CI and AI-reviewer cycles — triage every comment (most AI feedback is noise), fix only what's real, reply to false positives with evidence, and keep looping until the PR is green and quiet. Use whenever the user says "handle reviews", "review loop", "address reviewers", "wait for CI", or after creating a PR with CI checks or AI reviewers like CodeRabbit, Devin, Copilot, Greptile, Bito. Also use when a cloud agent or human is pushing concurrently to the same PR, when comments keep bouncing across many rounds, or when an AI reviewer is generating false positives.
---

# PR Review Loop

You are the PR closer. Wait for CI and reviewers, **triage every signal**, fix what's real, reply to noise, push, and **keep looping until the PR is green and quiet**. This is a long-running task. You do not stop after one round.

## Mental model

A review round is:

1. **Sync** local with remote (someone else may have pushed)
2. **Wait** for CI + AI reviewers to finish
3. **Pull** review state via the canonical queries below
4. **Triage** each open signal — most AI feedback is noise; verify before fixing
5. **Fix** real issues, **reply** to noise with evidence, **resolve** the thread
6. **Verify** locally (tests, types, lint)
7. **Push** with `--force-with-lease`, go back to step 1

Failure modes to avoid:

- **Stopping early.** CodeRabbit / Devin / Copilot routinely post 3–8 rounds before they settle. Don't quit after one. There is no fixed round limit — exit only when the exit conditions are met (see below).
- **Fixing noise.** AI reviewers generate plenty of false positives, style preferences, and "consider extracting a helper" suggestions that the codebase doesn't want. Every comment must be reproduced/verified before you change code for it.
- **Tool flailing.** `gh`, REST, and GraphQL each expose a different slice of PR data. Use the table below; do not improvise. Resolved/unresolved thread state is **only** in GraphQL.
- **Stomping concurrent pushes.** A cloud agent or human may be pushing while you work. Fetch+rebase every round and always use `--force-with-lease`.

## Setup

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER=${REPO%/*}; NAME=${REPO#*/}
PR_NUM=$(gh pr view --json number -q .number)
HEAD_BRANCH=$(gh pr view --json headRefName -q .headRefName)
ME=$(gh api user --jq .login)
```

Set these once at the start. Re-read them only if you switch PRs.

## Canonical queries — pick the right tool the first time

`gh`, REST, and GraphQL overlap but are not interchangeable. Use this table; flipping between APIs mid-loop is the #1 cause of wasted rounds.

| What you want | Tool | How |
|---|---|---|
| List required + optional check states | `gh` | `gh pr checks $PR_NUM --json name,state,bucket,link,workflow` |
| Wait until checks finish (blocking) | `gh` | `gh pr checks $PR_NUM --watch --fail-fast` |
| Logs for a failing run | `gh` | `gh run view <run-id> --log-failed` (run-id from the `link` above) |
| Inline code-review comments | REST | `gh api repos/$REPO/pulls/$PR_NUM/comments` |
| Top-level reviews (APPROVED / CHANGES_REQUESTED) | REST | `gh api repos/$REPO/pulls/$PR_NUM/reviews` |
| PR-level (issue-style) comments — CodeRabbit walkthroughs land here | REST | `gh api repos/$REPO/issues/$PR_NUM/comments` |
| **Unresolved threads** (the source of truth for "is this still open?") | GraphQL | see `fetch_unresolved` below |
| Reply to an inline comment in its thread | REST | `gh api -X POST repos/$REPO/pulls/$PR_NUM/comments/<id>/replies -f body=...` |
| Reply to a PR-level discussion comment | REST | `gh api -X POST repos/$REPO/issues/$PR_NUM/comments -f body=...` |
| **Mark a thread resolved** | GraphQL | `resolveReviewThread` mutation, takes the thread node id |

REST does **not** expose `isResolved` on threads. If you skip GraphQL you will re-process closed threads every round.

### The one query you'll run most: unresolved threads

**Paginate.** A PR that's been through a few rounds easily exceeds 100 threads. `reviewThreads(first:100)` alone silently drops the rest, so you'll think the PR is quiet when 30+ threads are still hiding on page 2. Use `--paginate --slurp` and merge pages with `jq` (note: `--slurp` cannot be combined with `--jq`, so pipe to `jq` instead):

```bash
fetch_unresolved() {
  gh api graphql --paginate --slurp -f query='
    query($owner:String!, $name:String!, $pr:Int!, $endCursor:String) {
      repository(owner:$owner, name:$name) {
        pullRequest(number:$pr) {
          reviewThreads(first:100, after:$endCursor) {
            pageInfo { hasNextPage endCursor }   # required for --paginate
            nodes {
              id                 # thread node id -> resolveReviewThread
              isResolved
              isOutdated
              path
              line
              comments(first:1) {
                nodes { fullDatabaseId author { login } body }   # [0] -> REST /replies
              }
            }
          }
        }
      }
    }' -f owner="$OWNER" -f name="$NAME" -F pr="$PR_NUM" \
  | jq '[.[].data.repository.pullRequest.reviewThreads.nodes[]]
        | map(select(.isResolved == false
                     and (.comments.nodes[0].author.login != "'"$ME"'")))'
}
```

This returns **every** unresolved thread across all pages, minus ones you opened yourself. Each carries `id` (→ `resolveReviewThread`) and `comments.nodes[0].fullDatabaseId` (→ REST `/replies`). Sanity-check the count against the PR's "conversations" tab the first time; if it looks low, your pagination is broken.

**Do not filter out `isOutdated`.** Outdated only means the line moved or the diff changed — the thread is still **open** and counts against "quiet." An earlier version of this skill dropped outdated threads, which left a pile of stale-but-unresolved threads that never closed and a PR that was never actually quiet. Keep them in the queue. Treat `isOutdated == true` as a strong signal the issue was already addressed by a later commit: verify briefly, reply "addressed in `<sha>`", and **resolve** it.

### Resolving a thread

```bash
resolve_thread() {
  gh api graphql -f query='
    mutation($id:ID!) {
      resolveReviewThread(input:{threadId:$id}) { thread { isResolved } }
    }' -f id="$1" >/dev/null
}
```

Resolve a thread after you've addressed it — by fixing the code, replying with evidence that it's a false positive, or replying with a follow-up plan. The reviewer can always unresolve; closing the thread is the right default. Next iteration's `fetch_unresolved` automatically skips it, which is how you avoid re-processing across rounds.

### Replying to an inline comment

```bash
reply_inline() {
  gh api -X POST "repos/$REPO/pulls/$PR_NUM/comments/$1/replies" -f body="$2" >/dev/null
}
```

`$1` is the `fullDatabaseId` of any comment in the thread. The reply lands in that thread.

## The loop

### 1. Sync with remote

```bash
git fetch origin
git pull --rebase origin "$HEAD_BRANCH"
```

If the rebase conflicts, resolve and `GIT_EDITOR=true git rebase --continue`. Refuse to do anything else until your local branch is at-or-ahead of origin.

### 2. Wait for checks

```bash
gh pr checks "$PR_NUM" --watch --fail-fast || true
```

`--watch` blocks until the required CI checks settle — don't hand-roll a `sleep` loop for those. (AI reviewers are the exception: `--watch` often returns before they finish, so they get an explicit poll — see below.) The `|| true` is because `--watch` exits non-zero on failure, which is expected — we want to inspect failures, not bail.

If checks haven't started yet (no rows), give the CI 30s to wake up and re-check:

```bash
while [ "$(gh pr checks "$PR_NUM" --json state --jq 'length')" = "0" ]; do
  sleep 30
done
gh pr checks "$PR_NUM" --watch --fail-fast || true
```

For failed checks, pull the failed-step logs directly — don't skim summaries:

```bash
gh pr checks "$PR_NUM" --json name,state,bucket,link \
  --jq '.[] | select(.bucket=="fail") | "\(.name)\t\(.link)"' \
| while IFS=$'\t' read -r name link; do
    case "$link" in
      */runs/*)
        run_id=${link##*/runs/}; run_id=${run_id%%/*}
        echo "=== failing run: $name ($run_id) ==="
        gh run view "$run_id" --log-failed
        ;;
      *)
        echo "=== failing external check: $name -> $link ==="
        ;;
    esac
  done
```

**AI reviewers finish much later than CI — wait for them explicitly.** Tools like Devin Review / CodeRabbit run *per push* and often take 5–15+ minutes — longer than all of CI. Two traps:

- They post threads **while still "analyzing"** *and* a final batch when the check flips to terminal. A status of `pass` does **not** mean "no comments" — it just means the run finished; it can still have posted a dozen advisory threads. Always re-run `fetch_unresolved` *after* the reviewer check goes terminal.
- `gh pr checks --watch` returns when the *required* checks settle, which is often before the (usually non-required) reviewer check is done. This is the one place to poll a specific check rather than trust `--watch`:

```bash
# wait for a named reviewer check (e.g. "Devin Review") to reach a terminal state
while gh pr checks "$PR_NUM" --json name,state \
        --jq '.[] | select(.name=="Devin Review") | .state' \
      | grep -qiE 'pending|in_progress|queued'; do
  sleep 30
done
```

Only decide "quiet" after every reviewer you care about has gone terminal on the **current HEAD SHA**. Each push starts a fresh reviewer round, so expect to wait again after every fix. (Replies, resolves, and editing the PR description do **not** trigger a reviewer re-run — only new commits do. Editing the description *can* re-trigger other workflows like a security-review or codeowners check, which is harmless.)

### 3. Pull review state

```bash
fetch_unresolved | jq 'length'   # how many open threads
fetch_unresolved                 # full payload
gh api "repos/$REPO/pulls/$PR_NUM/reviews" \
  --jq '[.[] | {user:.user.login, state:.state, submitted_at}] | group_by(.user) | map(max_by(.submitted_at))'
gh api "repos/$REPO/issues/$PR_NUM/comments" \
  --jq '.[] | select(.user.login != "'"$ME"'") | {id, user:.user.login, created_at, body:.body[:200]}'
```

The grouped reviews query gives you each reviewer's **latest** state — that's what GitHub uses to decide whether the PR is approved.

### 4. Triage every open signal

This is the load-bearing step. For **every** unresolved thread and **every** failing check, do the following in order. Do not skip.

1. **Read the code — and the codebase around it.** This step decides everything; do it properly. Open the cited line, read ≥30 lines of context, then go deeper:
   - **Trace to the source.** Follow the call stack, the data's origin, and the actual config/constants/base classes — not just the cited line. The premise of a flag often lives two or three hops away (in a session factory, a constants file, a parent class). The whole finding can collapse once you read it.
   - **Find analogous patterns to learn the codebase's intent.** Grep for sibling code that does the same kind of thing — other endpoints in the router, other callers of the helper, the established "core" function. This is how you tell a *real bug* from an *established convention the whole repo follows*, and it shows you what a correct fix looks like: **match the siblings.** (Example: "this re-fetch lacks an `org_id` filter" is noise if every sibling endpoint does the same and middleware enforces the tenant boundary; but "this path doesn't handle a ServiceUser owner" is a real fix if the sibling approval paths already do and this one is the odd one out.)
   - **Separate pre-existing from PR-introduced.** `git grep` / `git log -S` against the PR base to see whether the flagged code is new in this PR or baseline. Baseline behavior shared with other call sites/transports is usually out of scope; a regression you introduced is not.
   - **Use intent signals, but not circular ones.** Docstrings and comments in code you did *not* touch are real evidence of design intent. A docstring or guard *you* added in this PR is not — never cite your own change to justify itself (subagents will do this; don't let them).

   If the cited line no longer exists or was rewritten, the thread is stale → reply with the SHA that addressed it and resolve. Never guess; validate every finding against the actual code.
2. **Reproduce the alleged problem — and check the reviewer's stated facts.** AI reviewers confidently assert premises that are simply wrong (e.g. "this session uses `expire_on_commit=True`" when it's `False`, or "`resume_devin` takes `requesting_user_id`" when it takes `user_id`). A wrong premise collapses the whole finding, so verify the premise against the actual code/config **before** you evaluate the conclusion. Then reproduce:
   - "This will crash on empty input" → write the failing test, run it, observe.
   - "This is O(n²)" → check the actual input size and whether it matters in production.
   - "Missing error handling" → trace whether the caller already handles it.
   - "Type error" → run the typechecker (`pnpm tsc`, `uv run mypy --strict`, `cargo check`).
   - "Race condition" → identify the two concurrent paths; if you can't, it isn't one.
3. **Classify** as exactly one of:

   | Class | Meaning | Action |
   |---|---|---|
   | **Real bug** | Reproducible failure / wrong output / security issue | Fix, then resolve |
   | **Real style issue project enforces** | Matches existing patterns or a lint rule the repo runs | Fix, then resolve |
   | **False positive** | Reviewer misread the code; not actually broken | Reply with specific counter-evidence (file:line + reasoning), then resolve |
   | **Noise / preference** | Cosmetic suggestion the codebase doesn't enforce (defensive null checks, redundant comments, "extract helper") | Reply briefly explaining why we don't apply this here, then resolve |
   | **Out of scope** | Valid but doesn't belong in this PR | Reply with follow-up plan or issue link, then resolve |
   | **Needs human input** | Ambiguous; depends on product intent the reviewer raised | Leave unresolved, mention the human reviewer, **continue the loop** — don't exit |
   | **Judgment / shared-code call** | A "fix" would touch shared or security-sensitive code (auth, etc.), change a public contract, or hinges on a real design trade-off | Don't change it unilaterally. Present the options + your recommendation to **the user you're working for** and get a decision; then reply on the thread with the rationale and resolve. Document load-bearing decisions in the PR description so reviewers (human and AI) stop re-flagging them |

4. **Act.** Fixes go in code; replies go via `reply_inline` or the issue-comments endpoint; close with `resolve_thread "$thread_id"`. A non-empty reply before resolving is almost always the right call — silent resolves frustrate reviewers.

5. **Move on.** Process every signal before you push. Batching reduces the number of round-trips and keeps commit history clean.

**High-volume rounds.** When a round drops 15–30 threads (common after a big push or a reviewer's first pass), one-at-a-time is slow and error-prone. Drive `fetch_unresolved` from a small script that maps a substring of each thread's first comment to a canned reply, then posts the reply and resolves — but **dry-run first**: print each thread's first line next to the reply it matched, eyeball that the categorization is right, *then* let it post. Threads that match no rule are exactly the ones that need real, individual attention — never auto-resolve an unmatched thread.

### 5. Verify locally

Before pushing, prove your fixes work. Skipping this is the second biggest cause of bouncing rounds:

- Run the tests touching the changed files
- Run the **exact** typechecker / linter / formatter the CI runs, over the **same file set CI covers — including test files**. (A real round bounced here: local pyright was run only on the source file, but CI type-checks tests too and caught a type error in the new test.)
- Re-run the reproducer from step 4.2 and confirm it now passes

### 6. Commit and push safely

```bash
git add -A
git commit -m "fix: address review feedback"     # or a more specific conventional-commit message

git fetch origin
git pull --rebase origin "$HEAD_BRANCH"          # absorb any concurrent push
git push --force-with-lease origin "$HEAD_BRANCH"
```

`--force-with-lease` aborts the push if the remote moved since your last fetch — exactly the protection you want when a cloud agent is also pushing. If push is rejected, **return to step 1**: the other agent's commits may have already addressed (or invalidated) some of your fixes.

### 7. Loop

Go back to step 1. Continue until **both**:

- All required checks are green (`bucket == pass` or `skipping`), with every AI reviewer terminal on the current HEAD SHA, AND
- `fetch_unresolved | jq 'length'` returns `0`.

Know your repo's *known-ignorable* non-green checks so they don't trap you in a fake loop: e.g. a Vercel deploy that fails on account/permissions ("author must have access to the project"), or a bot check that sits perpetually "Awaiting…". These aren't real gates — confirm once what they are, then don't let them block your definition of "green."

**Do not stop at an arbitrary round count.** If you keep making progress (each round closes threads or moves checks toward green), keep going. The only legitimate early-exit conditions are:

- Exit conditions above are met.
- You've made the same fix twice and it bounced both times — something deeper is wrong; surface it to the user.
- A human reviewer has posted a question that needs product/design input you can't supply.
- The user told you to stop.

On exit, print one line: rounds completed, threads closed, threads still open and why, final check state.

## Triage cheatsheet by reviewer

Different bots have different failure modes — calibrate accordingly:

- **CodeRabbit** — high noise floor. Posts a walkthrough comment (issue-style) + many inline suggestions tagged `🛠️ Refactor suggestion` / `⚠️ Potential issue` / `🧹 Nitpick`. Nitpicks are almost always noise. "Potential issue" is roughly 50/50; verify with a reproducer. "Refactor suggestion" is taste-based; only apply if it matches existing patterns.
- **Devin / Cognition reviewer** — higher signal but verbose; tags severity with emoji (🔴 bug, 🟡 medium, 🚩 consideration). 🔴s deserve a hard look but are still wrong sometimes — verify the premise. It re-reviews on every push and **will flag the same code both ways across rounds** (e.g. "missing guard" one round, "guard is inconsistent" the next). Don't chase it round-trip: make one coherent decision, implement it, reply with the rationale, and resolve. A green "Devin Review" check still carries threads to triage.
- **Copilot review** — pattern-matches on common idioms, often wrong about project-specific conventions. Always verify against neighboring code before accepting.
- **Greptile** — usually high signal on cross-file consistency; verify by reading the other files it cites.
- **Human reviewers** — always take seriously, but still verify with a reproducer before changing code. Reply with evidence, not "fixed in <sha>".

When in doubt, reproduce. A 30-second test beats a 10-minute argument.

## Concurrency: cloud agent / human pushing at the same time

You can detect a concurrent contributor by comparing `origin/$HEAD_BRANCH` to your last-known SHA:

```bash
git fetch origin
behind=$(git rev-list --count "HEAD..origin/$HEAD_BRANCH")
[ "$behind" -gt 0 ] && echo "$behind new commits on origin since last sync"
git log "origin/$HEAD_BRANCH" --since="15 minutes ago" --pretty='%h %an %s'
```

If someone else is pushing:

1. `git pull --rebase` — incorporate their work. `--force-with-lease` makes this safe.
2. Re-run `fetch_unresolved` — their commit may have resolved threads, or GitHub may have marked threads `isOutdated` because their changes moved the lines.
3. **Drop items they fixed from your queue.** Don't redo work; verify their fix and resolve the thread instead.
4. Continue the loop. If you and the other contributor are addressing the **same** thread, whoever pushes first wins — verify their fix passes locally and move on.

If the rebase conflicts repeatedly with the other contributor's changes, you are racing on the same files. Stop and surface this to the user; coordination beats further force-pushing.

## When everything seems stuck

Two rounds in a row with no progress (no threads closed, no checks moving from fail to pass) means you've hit one of:

- **Same fix bouncing** — your change isn't actually addressing the reviewer's concern. Re-read the comment, ask a clarifying reply, or escalate to the user.
- **Flaky CI** — re-run the check (`gh run rerun <run-id> --failed`) once. If it fails again, treat it as a real failure.
- **Reviewer is wrong but won't let it go** — escalate to a human maintainer.

Don't grind forever on a stuck round; one polite escalation is better than ten pointless commits.

## Quick reference

| Task | Command |
|---|---|
| Wait for checks | `gh pr checks $PR_NUM --watch --fail-fast` |
| Wait for a named AI reviewer | poll `gh pr checks $PR_NUM --json name,state --jq '.[]\|select(.name=="Devin Review").state'` until not `pending` |
| List failing checks | `gh pr checks $PR_NUM --json name,state,bucket,link --jq '.[] \| select(.bucket=="fail")'` |
| Failing run logs | `gh run view <run-id> --log-failed` |
| Unresolved threads (canonical) | `fetch_unresolved` (GraphQL helper above) |
| Latest review state per reviewer | `gh api repos/$REPO/pulls/$PR_NUM/reviews --jq 'group_by(.user.login) \| map(max_by(.submitted_at))'` |
| Reply to inline comment | `reply_inline <fullDatabaseId> "body"` |
| Reply to PR-level comment | `gh api -X POST repos/$REPO/issues/$PR_NUM/comments -f body=...` |
| Resolve thread | `resolve_thread <threadId>` |
| Safe push during a race | `git push --force-with-lease origin $HEAD_BRANCH` |
| Detect concurrent pushes | `git rev-list --count HEAD..origin/$HEAD_BRANCH` |
| Re-run flaky check | `gh run rerun <run-id> --failed` |
