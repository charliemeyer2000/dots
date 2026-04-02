---
name: review-loop
description: Monitor a PR for CI checks and reviewer comments, address feedback, and push until approved. Use when the user says "handle reviews", "review loop", "wait for reviewers", or after creating a PR that has CI/AI reviewers configured. Also use after pushing a branch when you know there are CI checks or automated reviewers (like Devin) that will run.
---

# PR Review Loop

Monitor a PR for CI and reviewer activity, address feedback, and push until clean. The critical design choice here is **shell-level polling** — the wait happens inside a single shell command so the agent pays zero tokens while checks run. Never poll with repeated exec/sleep calls from agent context.

## Setup

```bash
PR=$(gh pr view --json number -q .number)
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

## The Loop

### 1. Wait for checks to settle (shell-level)

Run the bundled script from this skill's directory. It blocks in the shell until every check finishes (pass or fail) or times out — the agent does nothing until it returns:

```bash
bash "<skill-dir>/scripts/wait-for-pr.sh" "$PR"
```

Default: 40 polls × 30 s = 20 min timeout. Override with positional args:

```bash
bash "<skill-dir>/scripts/wait-for-pr.sh" "$PR" 60 15   # 60 polls, 15s apart
```

The script prints a final summary: which checks passed/failed and a `RESULT:` line.

### 2. Read review comments

Once checks settle, pull any comments left by reviewers (AI or human):

```bash
# Inline file comments (Devin, GitHub reviewers, etc.)
gh api "repos/${OWNER_REPO}/pulls/${PR}/comments" \
  --jq '.[] | {path: .path, line: .line, body: .body, user: .user.login}'

# Top-level review bodies
gh api "repos/${OWNER_REPO}/pulls/${PR}/reviews" \
  --jq '.[] | select(.body != "") | {state: .state, body: .body, user: .user.login}'
```

### 3. Decide what to do

- **All checks passed + no comments** → go to Exit.
- **Checks failed** → read the failing check logs (`gh pr checks "$PR"`), fix the issue.
- **Review comments exist** → for each comment: fix the code if feedback is valid, or reply explaining why no change is needed.

### 4. Push and repeat

```bash
git add -A && git commit -m "fix: address review feedback" && git push
```

Go back to step 1.

## Exit

Stop when checks pass and there are no unresolved comments. Print a short summary:

```
Review loop done: <N> round(s), <M> comment(s) addressed.
```
