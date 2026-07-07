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

Bottom-up with squash. First check the repo setting — it decides the retarget flow:

```bash
gh api repos/OWNER/REPO --jq .delete_branch_on_merge
```

**`true`** — merge with plain `gh pr merge --squash` and **never pass `--delete-branch`**. Auto-delete fires AFTER retargeting completes, so dependents retarget race-free; the explicit flag is what races and closes dependent PRs.

**`false`** — GitHub won't retarget for you. `gh pr edit <next> --base main` BEFORE deleting any branch (delete first and the dependent closes).

Per-level safety loop: before touching a PR, assert it is OPEN with base `main`. After merging, assert state MERGED. After the parent merges, poll the dependent until base is `main` — abort loudly if it goes CLOSED.

### Bringing the next PR up to date: restack, not update-branch

`gh api update-branch` works only until a PR modifies a file that a LOWER PR in the stack CREATED. Once the lower PR squash-merges, main's copy and the branch's copy of that file have no common ancestor → add/add conflict → HTTP 422 "merge conflict between base and head". Restack-after-each-merge has the same CI cost and no conflicts:

```bash
# Before merging anything, snapshot each PR's reviewed diff:
git diff "$parent..$branch" | grep -vE '^index |^@@' > "/tmp/$branch.reviewed"

# After each squash-merge:
git fetch origin
git checkout <leaf>
git rebase origin/main   # updateRefs: already-merged commits auto-drop (content is upstream)

# Verify each remaining PR's diff is unchanged, then batch push:
git diff "$parent..$branch" | grep -vE '^index |^@@' | diff "/tmp/$branch.reviewed" -
git push --force-with-lease origin <remaining-branches>
```

### CI budget and required checks

Required checks re-run per level either way — update-branch mints a merge commit, restack mints new SHAs. Budget one full CI cycle per stack level. `strict_required_status_checks_policy=false` spares the "branch up to date" requirement, not the per-commit required checks.

```bash
gh pr checks <pr> --required
```

PRs based on stack branches report "no required checks" — the required set only materializes once the PR is retargeted to main, so previously-ignorable failing contexts can suddenly become merge-blocking.

### Stale bot status contexts

Workflows filtered `on: pull_request: branches: [main]` (e.g. a security-review bot posting commit statuses) never fire while a PR is based on a stack branch — stale failure statuses linger and turn blocking after retarget. They refresh on the first synchronize after retarget (update-branch or force-push both count). If the bot's session is dead and never posts a verdict, force a fresh run with draft→ready:

```bash
gh pr ready <pr> --undo && sleep 5 && gh pr ready <pr>   # fires ready_for_review
```

### merge_stack()

```bash
merge_stack() {
  local owner_repo="$1" ; shift ; local prs=("$@")
  local auto=$(gh api "repos/$owner_repo" --jq .delete_branch_on_merge)
  local last=$(( ${#prs[@]} - 1 ))
  for i in "${!prs[@]}"; do
    local pr="${prs[$i]}"
    local st=$(gh pr view "$pr" --repo "$owner_repo" --json state,baseRefName --jq '.state + " " + .baseRefName')
    [[ "$st" != "OPEN main" ]] && { echo "ERROR: #$pr is '$st', expected 'OPEN main'"; return 1; }
    gh pr checks "$pr" --repo "$owner_repo" --required --watch || return 1
    gh pr merge "$pr" --squash --repo "$owner_repo"   # never --delete-branch
    [[ $(gh pr view "$pr" --repo "$owner_repo" --json state --jq .state) != "MERGED" ]] \
      && { echo "ERROR: #$pr did not merge"; return 1; }
    [[ "$i" -eq "$last" ]] && break
    local next="${prs[$((i + 1))]}"
    if [[ "$auto" == "true" ]]; then
      until [[ $(gh pr view "$next" --repo "$owner_repo" --json baseRefName --jq .baseRefName) == "main" ]]; do
        [[ $(gh pr view "$next" --repo "$owner_repo" --json state --jq .state) == "CLOSED" ]] \
          && { echo "ERROR: #$next closed instead of retargeted"; return 1; }
        sleep 5
      done
    else
      gh pr edit "$next" --repo "$owner_repo" --base main   # retarget BEFORE deleting any branch
    fi
    # Now restack remaining branches onto origin/main and force-push (see above).
    # gh api update-branch also works — until a PR touches a file a lower PR created (422).
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
| Auto-delete setting | `gh api repos/o/r --jq .delete_branch_on_merge` |
| Restack after merge | `git fetch origin && git checkout <leaf> && git rebase origin/main` |
| Required checks | `gh pr checks <pr> --required` |
| Refresh dead bot check | `gh pr ready <pr> --undo && sleep 5 && gh pr ready <pr>` |
| Walk stack | `walk_stack "owner/repo" "<root>"` |
| Find leaves | `find_leaves "owner/repo" "<root>"` |
