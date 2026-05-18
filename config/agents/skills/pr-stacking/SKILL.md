---
name: pr-stacking
description: Work with stacked GitHub PRs — creating a stack, rebasing/restacking after base changes, and merging bottom-up. Use when the user mentions stacked PRs, dependent PRs, PR chains, rebasing a stack, merging a stack, or when you detect a PR whose base branch is another PR's head branch.
---

# Stacked PRs

## Creating a stack

A stack is just a chain of branches where each PR targets the one below it instead of `main`.

```
main ← branch-a (PR #1) ← branch-b (PR #2) ← branch-c (PR #3)
```

```bash
# Start the base
git checkout main && git checkout -b feat/backend
# ... commit work ...
gh pr create --base main

# Stack on top
git checkout -b feat/frontend  # branches from feat/backend
# ... commit work ...
gh pr create --base feat/backend
```

Each PR's diff only shows its own layer. Reviewers see isolated changes.

## Restacking after base changes

When commits are added to a branch lower in the stack, rebase each branch above it in order:

```bash
# You changed feat/backend. Now update feat/frontend:
git checkout feat/frontend
git rebase feat/backend
git push --force-with-lease

# If there's a third layer:
git checkout feat/api-tests
git rebase feat/frontend
git push --force-with-lease
```

Rebase one layer at a time, bottom-up. Resolve conflicts at each layer before moving to the next.

## Merging a stack

Merge bottom-up with squash. The critical detail: **do not pass `--delete-branch` to `gh pr merge` on any PR except the top of the stack.**

### Why `--delete-branch` breaks stacks

`gh pr merge --delete-branch` sends a separate `DELETE /git/refs` API call immediately after the merge. This races with GitHub's server-side post-merge processing. GitHub's auto-retarget (which updates dependent PRs to point at the merged PR's base) is triggered by the server's own `delete_branch_on_merge` hook, not by client-side ref deletions. When `gh`'s DELETE arrives first, GitHub treats it as a manual branch deletion and **closes** dependent PRs instead of retargeting them.

If `delete_branch_on_merge` is enabled in repo settings (check with `gh api repos/{owner}/{repo} --jq .delete_branch_on_merge`), the branch gets cleaned up automatically by the server — in the correct order, with retarget happening first.

### Step-by-step

```bash
# 1. Merge the base PR (no --delete-branch)
gh pr merge <base-pr> --squash

# 2. Wait a few seconds, then verify retarget
sleep 5
gh pr view <next-pr> --json state,baseRefName
# expect: state=OPEN, baseRefName=main

# 3. Update the next PR's branch against main
gh api repos/{owner}/{repo}/pulls/<next-pr>/update-branch -X PUT

# 4. Wait for CI, then merge
gh pr checks <next-pr> --required --watch
gh pr merge <next-pr> --squash
# Use --delete-branch only on the LAST PR in the stack (nothing depends on it)
```

Repeat steps 2-4 for each layer.

### If retarget fails (PR gets closed)

This happens if `--delete-branch` was used or the server didn't retarget in time. Recovery:

```bash
# Recreate the deleted base branch pointing at main
MAIN_SHA=$(gh api repos/{owner}/{repo}/git/ref/heads/main --jq '.object.sha')
gh api repos/{owner}/{repo}/git/refs -X POST \
  -f ref="refs/heads/<deleted-branch>" -f sha="$MAIN_SHA"

# Reopen the PR
gh pr reopen <pr-number>

# Retarget to main
gh api repos/{owner}/{repo}/pulls/<pr-number> -X PATCH -f base=main

# Clean up the temporary branch
gh api repos/{owner}/{repo}/git/refs/heads/<deleted-branch> -X DELETE
```
