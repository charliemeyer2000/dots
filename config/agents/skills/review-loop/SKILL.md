---
name: review-loop
description: Monitor a PR for AI reviewer comments, address them, and push until approved. Use when the user says "handle reviews", "review loop", "wait for reviewers", or after creating a PR that has CI/AI reviewers configured.
---

# PR Review Loop

Repeatedly check for reviewer comments on the current PR, address them, and push until there's nothing left.

## Loop

1. Get the current PR number (`gh pr view --json number -q .number`)
2. Wait for pending reviews to complete — poll `gh pr checks` and `gh pr reviews` every 30 seconds until new comments appear or all checks pass
3. Read review comments (`gh api repos/{owner}/{repo}/pulls/{number}/comments`)
4. For each unresolved comment: fix the code if the feedback is valid, or reply explaining why no change is needed
5. Commit, push
6. Go to step 2

## Exit

Stop when a polling cycle returns no new comments and all checks pass. Print a one-line summary of how many rounds and what changed.
