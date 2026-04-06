---
name: review-loop
description: Monitor a PR for CI checks and AI reviewer comments, address them, and push until approved. Use when the user says "handle reviews", "review loop", "wait for reviewers", or after creating a PR that has CI/AI reviewers configured.
---

# PR Review Loop

Wait for CI checks and AI reviewers to finish on a PR, address their feedback, push fixes, and repeat until everything passes with no unresolved comments.

## Setup

Get the repo and PR number:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR_NUM=$(gh pr view --json number -q .number)
```

## Loop

### Step 1: Wait for checks to finish

Use `gh pr checks` with `--watch` to block until all checks complete:

```bash
gh pr checks "$PR_NUM" --watch --fail-fast 2>&1
```

`--watch` blocks until checks finish — do NOT use `sleep` to poll manually. If `--watch` times out or isn't available, fall back to a shell loop:

```bash
while gh pr checks "$PR_NUM" 2>&1 | grep -q "pending"; do sleep 30; done
```

### Step 2: Collect review feedback

Once checks are done, fetch all review comments and reviews:

```bash
# PR review comments (inline code comments)
gh api "repos/${REPO}/pulls/${PR_NUM}/comments" --jq '.[] | {id: .id, user: .user.login, path: .path, line: .line, body: .body, created_at: .created_at}'

# PR reviews (top-level approve/request-changes/comment)
gh api "repos/${REPO}/pulls/${PR_NUM}/reviews" --jq '.[] | {id: .id, user: .user.login, state: .state, body: .body, submitted_at: .submitted_at}'

# Issue-level comments (general discussion)
gh api "repos/${REPO}/issues/${PR_NUM}/comments" --jq '.[] | {id: .id, user: .user.login, body: .body, created_at: .created_at}'
```

Ignore comments from the PR author (yourself). Focus on comments from AI reviewers (e.g. devin, coderabbit, copilot) and human reviewers.

### Step 3: Address feedback

For each piece of unresolved feedback:

- If the feedback is valid: fix the code
- If the feedback is wrong or not applicable: reply explaining why with `gh api -X POST "repos/${REPO}/pulls/${PR_NUM}/comments/${comment_id}/replies" -f body="..."`

### Step 4: Push fixes

If you made changes, commit and push:

```bash
git add -A && git commit -m "fix: address review feedback" && git push
```

Then go back to **Step 1**.

### Step 5: Exit

Stop looping when:
- All checks pass, AND
- No new unresolved review comments since last push

Print a one-line summary: how many rounds, what was changed, final check status.

## Important

- **Prefer `gh pr checks --watch` over `sleep` polling.** Only fall back to a `sleep` loop if `--watch` is unavailable.
- `gh pr reviews` is NOT a valid command — always use `gh api` for review data.
- Keep track of which comments you've already addressed (by ID or timestamp) so you don't re-process them.
- If you've completed 5 rounds, warn the user and ask whether to keep going.
