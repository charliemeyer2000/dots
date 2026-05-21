---
name: pr-stacking
description: Work with stacked GitHub PRs — creating stacks, restacking after changes anywhere in the stack, batch-rebasing 9+ deep stacks in one command, merging bottom-up, and tracing/visualizing an existing stack's topology and CI status. Use when the user mentions stacked PRs, dependent PRs, PR chains, rebasing a stack, restacking, merging a stack, editing a commit deep in a stack, tracing or inspecting a stack, summarizing the state of a stack, or when you detect a PR whose base branch is another PR's head branch. Also triggers for questions about --update-refs, git absorb with stacks, force-pushing an entire stack, or normalizing GitHub statusCheckRollup across CheckRun and StatusContext entries.
---

# Stacked PRs

Raw git with `--update-refs` (enabled globally), `git-absorb`, and `gh`. No wrapper tools needed.

## Prerequisites

`rebase.updateRefs` is enabled globally — a rebase from the leaf of a 16-deep stack rewrites every intermediate branch ref in one pass.

`git-absorb` is on PATH — surgically inserts fixes into the correct commit.

```bash
git config --global rerere.enabled true
git config --global rerere.autoUpdate false
```

---

## Five rules (read these first)

Every stacking failure traces to violating one of these:

1. **Verify before committing.** Before fixing code in a stack, `git show <branch>:<file>` to confirm the functions/types/imports you reference exist at that branch. If they don't, your fix belongs on a later branch.

2. **Never `--ours` in rebase.** In rebase context, "ours" = base branch, "theirs" = your commit being replayed. `git checkout --ours` silently drops your PR's changes. Always resolve manually or use `--theirs`.

3. **Validate on the changed branch.** Run linter + type-checker + tests on the specific branch you modified, not just the leaf. A 10-second type-check catches wrong-level calls before they pollute 14 downstream branches.

4. **Batch push, never push incrementally.** Push all branches at once after all rebases complete. Pushing one-at-a-time triggers CI on intermediate broken states.

5. **Use `--onto` for reverts.** After reverting a commit on base A, `git rebase A` on child B says "already up to date" — B already contains A's commits from a prior rebase. Use `git rebase --onto` instead.

---

## Creating a stack

```bash
git checkout main && git checkout -b feat/api
# ... commit ...
gh pr create --base main

git checkout -b feat/auth   # branches from feat/api
# ... commit ...
gh pr create --base feat/api

git checkout -b feat/tests  # branches from feat/auth
# ... commit ...
gh pr create --base feat/auth
```

---

## Restacking (one command)

After modifying any branch, checkout the leaf and rebase onto the changed base. `--update-refs` rewrites every intermediate branch pointer automatically:

```bash
git checkout feat/tests    # leaf of the stack
git rebase feat/api        # rebases feat/auth AND feat/tests in one pass
```

For tree-shaped stacks (a branch has multiple children), rebase from each leaf:

```bash
for leaf in $(find_leaves "owner/repo" "feat/api"); do
  git checkout "$leaf"
  git rebase feat/api
done
```

After ALL rebases complete, batch push:

```bash
git push --force-with-lease origin feat/api feat/auth feat/tests
# Or for deep stacks:
walk_stack "owner/repo" "feat/api" | tail -n +2 | xargs git push --force-with-lease origin
```

---

## Fixing code in a stack

### Step 1: Find the right branch (MANDATORY)

```bash
# Which branch introduced this function?
git log --all --oneline -S "def create_api_key" -- path/to/sdk.py

# Verify the API you're calling exists at that level
git show feat/api:path/to/sdk.py | grep -A 10 "def create_api_key"
```

**If the parameter/type/import doesn't exist at that branch, your fix belongs on a later branch.** This is the single most expensive mistake — code that works on the leaf but breaks every intermediate PR.

### Step 2: Apply the fix

**Option A — `git absorb` (preferred).** Stage your fix on the leaf, absorb places it in the right commit automatically:

```bash
git checkout feat/tests    # leaf — all commits visible
git add -A
git absorb --base feat/api --force-author --and-rebase
```

Dry run first: `git absorb --base feat/api --dry-run`

**Option B — amend + rebase.** For single-commit branches:

```bash
git checkout feat/api
git add -A && git commit --amend --no-edit
git checkout feat/tests
git rebase feat/api
```

**Option C — fixup + autosquash.** When you know the target SHA:

```bash
git checkout feat/api
git add -A
git commit --fixup <SHA>
git checkout feat/tests
GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash feat/api~1
```

### Step 3: Validate on the changed branch (MANDATORY)

```bash
git checkout feat/api    # the branch you actually changed
git grep -nE '^(<<<<<<<|>>>>>>>|=======$)'   # conflict markers
# Run project linter, type-checker, tests
# ONLY THEN push (step 4)
```

### Step 4: Batch push

```bash
git push --force-with-lease origin feat/api feat/auth feat/tests
```

---

## Syncing with trunk

```bash
git checkout main && git pull
git checkout feat/tests    # leaf
git rebase main            # --update-refs cascades everything
# Validate, then:
git push --force-with-lease origin feat/api feat/auth feat/tests
```

---

## Cascading a revert (the --onto trap)

After reverting a commit on branch A, plain `git rebase A` on child B says "already up to date" — B's history already includes A's (bad) commits from a prior rebase. Force a fresh replay:

```bash
# Save the old base tip before reverting
OLD_BASE=$(git rev-parse feat/api)

# Revert on the base
git checkout feat/api
git revert <bad-SHA> --no-edit

# Replay child branches onto the new base
git checkout feat/auth
git rebase --onto feat/api $OLD_BASE feat/auth

git checkout feat/tests
git rebase --onto feat/auth $OLD_AUTH feat/tests
```

Or reset children to their base and cherry-pick their own commits:

```bash
CHILD_SHA=$(git rev-parse feat/auth)  # save the commit
git checkout feat/auth
git reset --hard feat/api             # align with fixed base
git cherry-pick $CHILD_SHA            # replay just this branch's commit
```

---

## Conflict resolution

### Resolve in place, never abort

Aborting throws away all prior conflict resolutions in the same rebase:

```bash
git rebase feat/api   # hits conflict
git diff --name-only --diff-filter=U            # see conflicting files
# Fix conflicts manually (NEVER --ours)
git add -A
GIT_EDITOR=true git rebase --continue
```

Always set both `GIT_EDITOR=true` and `GIT_SEQUENCE_EDITOR=true` for non-interactive rebase.

### Fallback: layer-by-layer

If every commit conflicts differently, rebase one branch at a time:

```bash
walk_stack "owner/repo" "feat/api" | tail -n +2 | while IFS= read -r branch; do
  git checkout "$branch"
  parent=$(gh pr view "$branch" --json baseRefName --jq .baseRefName)
  git rebase "$parent"
  # resolve conflicts at this layer before moving to next
done
# Batch push after ALL layers are clean
```

---

## Stack discovery (GitHub API)

```bash
walk_stack() {
  local owner_repo="$1" root="$2"
  local -A visited=()
  local queue=("$root")
  while [[ ${#queue[@]} -gt 0 ]]; do
    local current="${queue[0]}"
    queue=("${queue[@]:1}")
    [[ -n "${visited[$current]+x}" ]] && continue
    visited["$current"]=1
    echo "$current"
    local children=""
    children=$(gh pr list --repo "$owner_repo" --base "$current" \
      --state open --json headRefName --jq '.[].headRefName' 2>/dev/null) || true
    [[ -z "$children" ]] && continue
    while IFS= read -r child; do
      [[ -n "$child" && -z "${visited[$child]+x}" ]] && queue+=("$child")
    done <<< "$children"
  done
}

find_leaves() {
  local owner_repo="$1" root="$2"
  local -a all=() ; local -A has_children=()
  while IFS= read -r b; do
    all+=("$b")
    local ch=""
    ch=$(gh pr list --repo "$owner_repo" --base "$b" \
      --state open --json headRefName --jq '.[].headRefName' 2>/dev/null) || true
    [[ -n "$ch" ]] && has_children["$b"]=1
  done < <(walk_stack "$owner_repo" "$root")
  for b in "${all[@]}"; do
    [[ -z "${has_children[$b]+x}" ]] && echo "$b"
  done
}
```

---

## CI status normalization

`statusCheckRollup` mixes `CheckRun` (`.conclusion`) and `StatusContext` (`.state`). Always coalesce:

```bash
gh pr view "$pr" --repo "$REPO" --json statusCheckRollup --jq '
  [.statusCheckRollup[] | (.conclusion // .state // .status // "PENDING")]
  | group_by(.) | map({key: .[0], value: length}) | from_entries'
```

Failing checks only:

```bash
gh pr view "$pr" --repo "$REPO" --json statusCheckRollup --jq '
  .statusCheckRollup[]
  | select((.conclusion // .state) == "FAILURE")
  | {name: (.name // .context), url: (.detailsUrl // .targetUrl)}'
```

---

## Merging stacks

Bottom-up with squash. **Never `--delete-branch` except on the topmost PR** — it races with GitHub's auto-retarget and closes dependent PRs.

```bash
merge_stack() {
  local owner_repo="$1" ; shift ; local prs=("$@")
  local last=$(( ${#prs[@]} - 1 ))
  for i in "${!prs[@]}"; do
    local pr="${prs[$i]}" flags="--squash"
    [[ "$i" -eq "$last" ]] && flags="$flags --delete-branch"
    gh pr merge "$pr" $flags --repo "$owner_repo"
    if [[ "$i" -lt "$last" ]]; then
      local next="${prs[$((i + 1))]}"
      sleep 5
      local state=$(gh pr view "$next" --repo "$owner_repo" --json state --jq .state)
      [[ "$state" != "OPEN" ]] && { echo "ERROR: #$next closed instead of retargeted"; return 1; }
      gh api "repos/$owner_repo/pulls/$next/update-branch" -X PUT
      gh pr checks "$next" --repo "$owner_repo" --required --watch
    fi
  done
}
```

Recovery if retarget fails:

```bash
MAIN_SHA=$(gh api repos/OWNER/REPO/git/ref/heads/main --jq '.object.sha')
gh api repos/OWNER/REPO/git/refs -X POST -f ref="refs/heads/<branch>" -f sha="$MAIN_SHA"
gh pr reopen <number>
gh api repos/OWNER/REPO/pulls/<number> -X PATCH -f base=main
gh api repos/OWNER/REPO/git/refs/heads/<branch> -X DELETE
```

---

## Quick reference

| Task | Command |
|---|---|
| Restack from leaf | `git checkout <leaf> && git rebase <changed-base>` |
| Restack tree | `for leaf in $(find_leaves ...); do git checkout "$leaf" && git rebase <base>; done` |
| Sync onto trunk | `git checkout <leaf> && git rebase main` |
| Batch push | `walk_stack "o/r" "<root>" \| tail -n +2 \| xargs git push --force-with-lease origin` |
| Absorb fix | `git add -A && git absorb --base <bottom> --force-author --and-rebase` |
| Absorb dry run | `git add -A && git absorb --base <bottom> --dry-run` |
| Fixup + autosquash | `GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash <base>` |
| Continue rebase | `GIT_EDITOR=true git rebase --continue` |
| Cascade a revert | `git rebase --onto <new-base> <old-base-sha> <child>` |
| Conflict markers | `git grep -nE '^(<<<<<<<\|>>>>>>>\|=======$)'` |
| Check API at level | `git show <branch>:<file> \| grep -A10 "def func"` |
| CI status | `(.conclusion // .state // .status // "PENDING")` |
| Merge stack | `merge_stack "owner/repo" 101 102 103` |
| Walk stack | `walk_stack "owner/repo" "<root>"` |
| Find leaves | `find_leaves "owner/repo" "<root>"` |
