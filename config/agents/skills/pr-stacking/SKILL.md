---
name: pr-stacking
description: Work with stacked GitHub PRs — creating stacks, restacking after changes anywhere in the stack, batch-rebasing 9+ deep stacks in one command, merging bottom-up, and tracing/visualizing an existing stack's topology and CI status. Use when the user mentions stacked PRs, dependent PRs, PR chains, rebasing a stack, restacking, merging a stack, editing a commit deep in a stack, tracing or inspecting a stack, summarizing the state of a stack, or when you detect a PR whose base branch is another PR's head branch. Also triggers for questions about --update-refs, git absorb with stacks, force-pushing an entire stack, or normalizing GitHub statusCheckRollup across CheckRun and StatusContext entries.
---

# Stacked PRs

## Environment

`rebase.updateRefs` is enabled globally — every rebase automatically moves intermediate branch pointers. A rebase from the top of a 9-deep stack rewrites every branch ref in one pass.

`git-absorb` is installed and on PATH — use it to surgically insert fixes into the correct commit without manual interactive rebase.

Enable `rerere` (reuse recorded resolution) before any stacked rebase work. It records conflict resolutions so that when the same conflict pattern recurs in later commits (common in deep stacks where a style/import fix cascades), git auto-resolves it:

```bash
git config --global rerere.enabled true
git config --global rerere.autoUpdate false
```

**Keep `rerere.autoUpdate false`.** With `autoUpdate true`, rerere applies a recorded resolution AND auto-stages it. But when the new conflict shape differs slightly from the recorded one (extra surrounding lines, slightly different indentation), the auto-applied resolution can leave **stray `>>>>>>>` or `=======` markers** without matching pairs — partial resolutions that silently break the build. With `false`, rerere still applies its best guess to your working tree, but you stage manually after verifying. Always run `git grep -nE '^(<<<<<<<|>>>>>>>|=======$)'` before continuing a rebase.

---

## Concepts

A stack is a chain of branches where each PR targets the one below it:

```
main ← feat/api (PR #1) ← feat/auth (PR #2) ← feat/tests (PR #3)
```

Each PR's diff shows only its own layer. Reviewers see isolated changes.

**Stack vocabulary** (matches Graphite conventions):
- **trunk**: the branch stacks merge into (`main`)
- **downstack**: PRs below the current one (ancestors)
- **upstack**: PRs above the current one (descendants)

---

## Creating a stack

```bash
git checkout main && git checkout -b feat/api
# ... commit work ...
gh pr create --base main

git checkout -b feat/auth   # branches from feat/api
# ... commit work ...
gh pr create --base feat/api

git checkout -b feat/tests  # branches from feat/auth
# ... commit work ...
gh pr create --base feat/auth
```

---

## Discovering a stack programmatically

Stacks aren't always linear chains. A single base branch might have multiple PRs branching off it (tree shape), some branches might be one-off PRs that happen to target the same base, and the graph can fork at any level. The discovery functions below handle all of these shapes.

**Pick a sensible root.** Don't walk from `main` in a large repo — every open PR against `main` becomes a candidate root and the recursive `gh` calls fan out across the whole repo (often timing out). Start from the bottom branch of your stack (the one that targets `main`). Find it first:

```bash
# Find candidate bottoms of the stack you care about
gh pr list --repo "$REPO" --base main --state open \
  --search "head:<prefix>" --json number,headRefName,title \
  --jq '.[] | "#\(.number) \(.headRefName) \(.title)"'
```

`head:<prefix>` matches anywhere in the head branch name (substring, not strict prefix). A stack may also include branches outside your namespace — e.g. cloud-agent commits land on `devin/...` or `copilot/...` branches stitched into your `cm/...` chain — so don't pre-filter discovery by your own branch prefix or by `--author "@me"`. Walk by base/head topology instead.

### Walk the full tree from a root

Returns every reachable branch in dependency order (parents before children), handling forks where multiple PRs share a base. Resilient to `set -euo pipefail`: empty results and transient `gh` failures fall back to "no children" rather than aborting the traversal.

```bash
# Recursively discover all open PRs reachable from a root branch.
# Outputs one line per branch in topological order (parents first).
# Handles tree-shaped stacks where a branch has multiple children.
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

    # Find ALL open PRs whose base is the current branch.
    # `|| true` prevents set -e from aborting on transient gh failures.
    local children=""
    children=$(gh pr list --repo "$owner_repo" --base "$current" \
      --state open --json headRefName --jq '.[].headRefName' 2>/dev/null) || true

    [[ -z "$children" ]] && continue

    while IFS= read -r child; do
      [[ -n "$child" && -z "${visited[$child]+x}" ]] && queue+=("$child")
    done <<< "$children"
  done
  return 0
}

# Usage: walk_stack "owner/repo" "feat/api"   # start from the bottom of YOUR stack
# Example output for a tree-shaped stack:
#   feat/api
#   feat/auth          <- child of feat/api
#   feat/auth-tests    <- child of feat/auth
#   feat/api-docs      <- another child of feat/api (fork)
```

Pass `--state all` instead of `--state open` if you need to include merged/closed branches (useful when reconstructing the history of a stack mid-merge).

### Get only the direct children of a branch

Useful when you only care about the immediate next layer:

```bash
children_of() {
  local owner_repo="$1" branch="$2"
  gh pr list --repo "$owner_repo" --base "$branch" \
    --state open --json number,headRefName \
    --jq '.[] | "\(.number)\t\(.headRefName)"'
}
```

### Find all leaf branches (tips of the stack)

Leaves are branches with no open PRs targeting them — these are the ones you checkout to rebase an entire sub-tree:

```bash
find_leaves() {
  local owner_repo="$1" root="$2"
  local -a all_branches=()
  local -A has_children=()

  while IFS= read -r branch; do
    all_branches+=("$branch")
    local children=""
    children=$(gh pr list --repo "$owner_repo" --base "$branch" \
      --state open --json headRefName --jq '.[].headRefName' 2>/dev/null) || true
    [[ -n "$children" ]] && has_children["$branch"]=1
  done < <(walk_stack "$owner_repo" "$root")

  for branch in "${all_branches[@]}"; do
    [[ -z "${has_children[$branch]+x}" ]] && echo "$branch"
  done
  return 0
}

# For a tree-shaped stack, rebase from EACH leaf:
for leaf in $(find_leaves "owner/repo" "feat/api"); do
  git checkout "$leaf"
  git rebase feat/api
done
```

### Trace a stack with PR metadata in one pass

When you need to summarise a stack (PR numbers, bases, line counts, CI, review status, titles) — for a status report, a code review handoff, or to figure out what's actually open — combine `walk_stack` with a single `gh pr list --head` call per branch. Don't hand-build a PR→base mapping, gh already knows it.

```bash
# Print one tab-separated line per stacked PR. Skips the root (it's the
# base of the bottom PR, not a stacked PR itself).
trace_stack() {
  local owner_repo="$1" root="$2"
  walk_stack "$owner_repo" "$root" | tail -n +2 | while IFS= read -r branch; do
    gh pr list --repo "$owner_repo" --head "$branch" --state open --limit 1 \
      --json number,title,baseRefName,headRefName,additions,deletions,changedFiles,reviewDecision,statusCheckRollup \
      --jq '.[] |
        ([.statusCheckRollup[] | (.conclusion // .state // .status // "PENDING")]
         | group_by(.) | map("\(length) \(.[0])") | join(", ")) as $ci |
        "#\(.number)\t\(.headRefName) <- \(.baseRefName)\t+\(.additions)/-\(.deletions) (\(.changedFiles) files)\tCI: \($ci)\tReview: \(.reviewDecision // "—")\t\(.title)"'
  done
}

# Usage: trace_stack "owner/repo" "feat/api" | column -t -s $'\t'
```

### CI status normalization (footgun)

`statusCheckRollup` is a heterogeneous list containing **two** GraphQL types:

- `CheckRun` (GitHub Actions, custom apps) — populated `.conclusion` (`SUCCESS`/`FAILURE`/`SKIPPED`/`NEUTRAL`/`CANCELLED`/`TIMED_OUT`) and `.status` (`COMPLETED`/`IN_PROGRESS`/`QUEUED`).
- `StatusContext` (legacy commit statuses — Buildkite, Devin Review, security scanners) — populated `.state` (`SUCCESS`/`FAILURE`/`PENDING`/`ERROR`) and no `.conclusion`/`.status`.

Naively grouping by `.conclusion` produces `null` keys for every `StatusContext` and breaks `from_entries`. Always coalesce across all three fields:

```bash
gh pr view "$pr" --repo "$REPO" --json statusCheckRollup --jq '
  [.statusCheckRollup[] | (.conclusion // .state // .status // "PENDING")]
  | group_by(.) | map({key: .[0], value: length}) | from_entries
'
# => {"SUCCESS":56,"SKIPPED":45,"FAILURE":1}
```

To list just the failing checks (useful for triaging which CI job is red across a stack):

```bash
gh pr view "$pr" --repo "$REPO" --json statusCheckRollup --jq '
  .statusCheckRollup[]
  | select((.conclusion // .state) == "FAILURE")
  | {name: (.name // .context), url: (.detailsUrl // .targetUrl)}
'
```

---

## Restacking after changes (the core workflow)

You made a commit to `feat/api` (the base), and PRs sit on top. You need them all rebased cleanly.

### Linear stack (chain)

Checkout the TOP of the stack and rebase onto the changed base. `--update-refs` (enabled globally) rewrites every intermediate branch pointer automatically:

```bash
# You just committed to feat/api. Restack everything above it.
git checkout feat/tests          # the topmost branch
git rebase feat/api              # rebases feat/auth AND feat/tests in one pass
```

Git sees that `feat/auth` points to a commit between `feat/api` and `feat/tests`. During rebase, it updates `feat/auth`'s ref to point at the new rebased commit. One rebase, all branches fixed.

After rebasing, push all updated branches:

```bash
# Batch push every branch in the stack
git push --force-with-lease origin feat/auth feat/tests

# Or for deep stacks, push from walk_stack output:
walk_stack "owner/repo" "feat/api" | tail -n +2 | xargs git push --force-with-lease origin
```

### Tree-shaped stack (forks / one-off branches)

When a branch has multiple children (e.g. `feat/api` has both `feat/auth` and `feat/api-docs` branching off it), a single rebase from one leaf only updates that leaf's path. You need to rebase from each leaf:

```bash
# Rebase every path through the tree
for leaf in $(find_leaves "owner/repo" "feat/api"); do
  git checkout "$leaf"
  git rebase feat/api
done

# Then batch push everything
walk_stack "owner/repo" "feat/api" | tail -n +2 | xargs git push --force-with-lease origin
```

`--update-refs` handles intermediate branches along each path, so if `feat/auth` sits between `feat/api` and `feat/auth-tests`, rebasing from `feat/auth-tests` updates `feat/auth` too. You only need one rebase per leaf, not per branch.

### Manual bottom-up rebase (fallback for complex topologies)

If the tree has cross-dependencies or you need per-layer conflict control:

```bash
# Rebase each layer in topological order (walk_stack outputs parents first)
walk_stack "owner/repo" "feat/api" | tail -n +2 | while IFS= read -r branch; do
  git checkout "$branch"
  # The PR's base branch is the parent to rebase onto
  parent=$(gh pr view "$branch" --json baseRefName --jq .baseRefName)
  git rebase "$parent"
  git push --force-with-lease origin "$branch"
done
```

Resolve conflicts at each layer before moving to the next.

---

## Editing a commit deep in the stack

You need to fix something in `feat/api` (the base) while 9 PRs sit above it.

### Approach 1: `git absorb` (preferred — zero manual steps)

`git absorb` analyzes your staged changes, figures out which existing commit they belong to, and creates targeted `fixup!` commits. Combined with `--update-refs`, this restacks everything in one shot.

**Always pass `--base`** to tell absorb the bottom of the stack. Without it, absorb only searches the last 10 commits (its default stack size), which is wrong for deep stacks:

```bash
git checkout feat/tests    # top of stack (so all commits are reachable)
# Make your fix anywhere in the working tree
git add -A
git absorb --base feat/api --and-rebase
```

**`--force-author`**: absorb refuses to modify commits by other authors by default. In team stacks where you're restacking someone else's work, pass this flag:

```bash
git absorb --base feat/api --force-author --and-rebase
```

**Dry run first** to see what absorb will do without creating any commits:

```bash
git add -A
git absorb --base feat/api --dry-run
# Output shows which hunks map to which commits
# If satisfied:
git absorb --base feat/api --force-author --and-rebase
```

**When absorb can't place every hunk**: absorb prints "Some file modifications did not have an available commit to fix up." Those changes stay staged. Handle them manually:

```bash
git absorb --base feat/api --force-author --and-rebase
# If partial: leftover changes are still staged
git diff --cached --stat                    # see what's left
git commit -m "fix: remaining changes"      # commit as new, or:
git commit --fixup <target-SHA>             # target a specific commit
GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash feat/api
```

If you want to review the fixup commits before squashing (skip `--and-rebase`):

```bash
git add -A
git absorb --base feat/api --force-author   # creates fixup! commits only
git log --oneline -20                        # review
GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash feat/api
```

For tree-shaped stacks, run absorb from each leaf (same as restacking):

```bash
for leaf in $(find_leaves "owner/repo" "feat/api"); do
  git checkout "$leaf"
  git add -A
  git absorb --base feat/api --force-author --and-rebase
done
```

### Approach 2: manual `commit --fixup` + autosquash

When you know exactly which commit to target (e.g. from `git log` or a PR review comment referencing a SHA):

```bash
git checkout feat/api
# Make the fix
git add -A
git commit --fixup <SHA-of-commit-to-fix>

# Rebase from the top of the stack (base is the parent of the fixup target)
git checkout feat/tests
GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash feat/api~1
git push --force-with-lease origin feat/api feat/auth feat/tests
```

### Approach 3: amend + rebase (simplest for single-commit branches)

If each branch has exactly one commit:

```bash
git checkout feat/api
git add -A && git commit --amend --no-edit

git checkout feat/tests
git rebase feat/api
# All intermediate branches updated automatically
```

---

## Syncing the stack with trunk

When `main` has advanced and you need to rebase the entire stack onto it:

```bash
git checkout main && git pull

# Linear stack: rebase from the top
git checkout feat/tests
git rebase main
git push --force-with-lease origin feat/api feat/auth feat/tests

# Tree-shaped stack: rebase from each leaf
for leaf in $(find_leaves "owner/repo" "main"); do
  git checkout "$leaf"
  git rebase main
done
walk_stack "owner/repo" "main" | tail -n +2 | xargs git push --force-with-lease origin
```

---

## Merging a stack

Merge bottom-up with squash. The critical rule: **do not pass `--delete-branch` to `gh pr merge` except on the topmost PR.**

### Why `--delete-branch` breaks stacks

`gh pr merge --delete-branch` sends a `DELETE /git/refs` API call immediately after merge. This races with GitHub's server-side post-merge processing. GitHub's auto-retarget (updating dependent PRs to point at the merged PR's base) is triggered by the server's own `delete_branch_on_merge` hook, not by client-side ref deletions. When `gh`'s DELETE arrives first, GitHub **closes** dependent PRs instead of retargeting them.

If `delete_branch_on_merge` is enabled in repo settings, the branch gets cleaned up automatically by the server in the correct order:

```bash
gh api repos/{owner}/{repo} --jq .delete_branch_on_merge
```

### Step-by-step merge

```bash
# 1. Merge the bottom PR (no --delete-branch)
gh pr merge <base-pr> --squash

# 2. Wait for retarget, then verify
sleep 5
gh pr view <next-pr> --json state,baseRefName
# Expect: state=OPEN, baseRefName=main

# 3. Update the next PR's branch against its new base
gh api repos/{owner}/{repo}/pulls/<next-pr>/update-branch -X PUT

# 4. Wait for CI, then merge
gh pr checks <next-pr> --required --watch
gh pr merge <next-pr> --squash

# Repeat 2-4 up the stack.
# Use --delete-branch ONLY on the LAST PR (nothing depends on it).
```

### Scripted merge for deep stacks

```bash
merge_stack() {
  local owner_repo="$1"
  shift
  local prs=("$@")  # PR numbers, bottom to top
  local last_idx=$(( ${#prs[@]} - 1 ))

  for i in "${!prs[@]}"; do
    local pr="${prs[$i]}"
    local flags="--squash"
    [[ "$i" -eq "$last_idx" ]] && flags="$flags --delete-branch"

    echo "Merging PR #$pr..."
    gh pr merge "$pr" $flags --repo "$owner_repo"

    if [[ "$i" -lt "$last_idx" ]]; then
      local next="${prs[$((i + 1))]}"
      echo "Waiting for retarget of PR #$next..."
      sleep 5

      # Verify retarget happened
      local state base
      state=$(gh pr view "$next" --repo "$owner_repo" --json state --jq .state)
      base=$(gh pr view "$next" --repo "$owner_repo" --json baseRefName --jq .baseRefName)

      if [[ "$state" != "OPEN" ]]; then
        echo "ERROR: PR #$next was closed instead of retargeted. See recovery steps."
        return 1
      fi

      # Update the branch
      gh api "repos/$owner_repo/pulls/$next/update-branch" -X PUT
      gh pr checks "$next" --repo "$owner_repo" --required --watch
    fi
  done
}

# Usage: merge_stack "owner/repo" 101 102 103 104
```

### Recovery: if retarget fails (PR gets closed)

```bash
# Recreate the deleted base branch pointing at main
MAIN_SHA=$(gh api repos/{owner}/{repo}/git/ref/heads/main --jq '.object.sha')
gh api repos/{owner}/{repo}/git/refs -X POST \
  -f ref="refs/heads/<deleted-branch>" -f sha="$MAIN_SHA"

# Reopen and retarget
gh pr reopen <pr-number>
gh api repos/{owner}/{repo}/pulls/<pr-number> -X PATCH -f base=main

# Clean up the temporary branch
gh api repos/{owner}/{repo}/git/refs/heads/<deleted-branch> -X DELETE
```

---

## Conflict resolution strategy for agents

When rebasing deep stacks, conflicts are common — especially when style/formatting commits touch the same files as feature commits. `rerere` helps with recurring patterns, but you'll still hit novel conflicts.

### Primary strategy: resolve in place and continue

Do NOT abort on the first conflict. Resolve it and keep the rebase going — aborting throws away all prior conflict resolutions in the same rebase:

```bash
git rebase feat/api   # hits a conflict

# 1. Inspect conflicting files
git diff --name-only --diff-filter=U

# 2. Resolve each file (edit to remove conflict markers)
# ... fix the files ...

# 3. Stage and continue (GIT_EDITOR=true prevents vim from opening for commit message)
git add -A
GIT_EDITOR=true git rebase --continue

# If the same pattern appears in a later commit, rerere may auto-resolve it.
# You'll see "Resolved 'file.py' using previous resolution" in the output.
```

**Critical**: always set both `GIT_EDITOR=true` and `GIT_SEQUENCE_EDITOR=true` when running rebase commands non-interactively. `GIT_SEQUENCE_EDITOR` prevents the todo-list editor; `GIT_EDITOR` prevents the commit-message editor during `--continue`. Missing `GIT_EDITOR` causes the agent to hang waiting for vim.

### Fallback: abort and go layer-by-layer

If conflicts are too tangled to resolve in place (e.g. every commit conflicts differently), abort and rebase one branch at a time to isolate which layer is the problem:

```bash
git rebase --abort

# Rebase each layer individually
walk_stack "owner/repo" "feat/api" | tail -n +2 | while IFS= read -r branch; do
  git checkout "$branch"
  parent=$(gh pr view "$branch" --json baseRefName --jq .baseRefName)
  git rebase "$parent"
  # Resolve conflicts here if any, then continue
  git push --force-with-lease origin "$branch"
done
```

---

## Pre-flight checks before pushing a restack

Run locally before force-pushing. Each catches a different class of restack bug:

```bash
# 1. Stray conflict markers (rerere can leave partial resolutions)
git grep -nE '^(<<<<<<<|>>>>>>>|=======$)'

# 2. If the project has database migrations (Alembic, Django, Prisma, etc.),
#    verify the migration chain is linear — migration "parent" references are
#    string identifiers in files that git rebase doesn't update.

# 3. Run the project's linter and formatter — the same commands CI runs.
#    Check .github/workflows/ or CI config to find the EXACT commands.
#    Common gotcha: CI may use a different formatter than you expect
#    (e.g. black vs ruff format, prettier vs biome).

# 4. Run the project's type-checker if applicable (tsc, pyright, mypy).
#    Type errors surface renamed identifiers (e.g. component prop renames
#    on main that the stack still uses the old names for).
```

## Restack failure modes (and how to fix each)

Most arise because **string identifiers in files don't auto-update during git rebase** — git only knows about textual diffs, not semantic references like migration parent pointers, component prop names, or import paths.

### Migration chain divergence after rebasing onto fresh trunk

**Symptom**: tests fail with "multiple heads" or "ambiguous migration" errors.

**Cause**: database migration files reference their parent by a **string identifier** (e.g. Alembic's `down_revision`, Django's `dependencies`). When the base PR is rebased onto a newer trunk, new trunk migrations appear alongside the PR's migration — but the PR's migration still points at the OLD trunk tip. Two parallel chains, two heads.

**Fix**: update the PR migration's parent reference to point at trunk's new tip. Absorb into the migration commit.

### Duplicate commits from a botched prior rebase

**Symptom**: identical declarations in code (e.g. same `useState` call twice, same import block duplicated). Linter reports redefined/shadowed identifiers.

**Cause**: a prior rebase failed partway and was resumed; the same logical commit got applied twice (different SHA, identical author timestamp + message).

**Detection**:
```bash
git log --format="%H %ai %s" <base>..HEAD | awk '
  { key=$2" "$3" "substr($0, index($0,$4)) }
  seen[key]++ { print "DUP:", $0 }
'
```

**Fix**: drop the duplicate with `git rebase -i` (mark as `drop`), then resolve conflicts in subsequent commits that depended on the duplicate's state.

### Renamed identifiers on trunk that the stack still uses

**Symptom**: type errors referencing old names (e.g. `Type '"old-name"' is not assignable to type '"new-name" | ...'`). Common with component prop renames, enum value changes, function signature changes.

**Cause**: trunk renamed something after the stack was branched. The stack's string literals / call sites still use the old name. Git rebase doesn't know these are semantically linked.

**Detection**: run the type-checker (`tsc`, `pyright`, `mypy`).

**Fix**: grep the stack for the old name, rename to new, absorb.

### "Your local changes would be overwritten by merge" on generated files

**Symptom**: rebase aborts even though `git status` shows a clean working tree. Common on auto-generated files (route manifests, lockfiles, codegen output) touched by many sequential commits.

**Cause**: after resolving an earlier conflict, the file's index state drifts from what the next commit's diff expects. This is a pre-merge checkout failure — `-X theirs` doesn't help.

**Fix**:
```bash
git checkout HEAD -- <generated-file>
git update-index --refresh
GIT_EDITOR=true git rebase --continue
```

If this recurs across many commits, loop:
```bash
while true; do
  git checkout HEAD -- <generated-file> 2>/dev/null || true
  git update-index --refresh >/dev/null 2>&1 || true
  out=$(GIT_EDITOR=true git -c commit.gpgsign=false rebase --continue 2>&1)
  [[ "$out" == *"Successfully rebased"* ]] && break
  [[ "$out" != *"would be overwritten"* ]] && { echo "$out"; break; }
done
```

After completion, verify the file matches origin — the loop shouldn't silently lose content:
```bash
diff <(git show origin/<branch>:<file>) <(git show <branch>:<file>)
```

### Duplicate import blocks from conflict resolution

**Symptom**: linter reports "redefined while unused" on imports that appear twice in the same file.

**Cause**: a conflict resolution kept both sides — the original imports AND the relocated imports. The second block often has a few UNIQUE imports mixed in with the duplicates.

**Fix**: always diff the two blocks before deleting:
```bash
diff <(sed -n '<start1>,<end1>p' <file>) <(sed -n '<start2>,<end2>p' <file>)
```
Merge unique imports into the canonical block, delete the duplicate block, then re-run the linter/formatter.

---

## When NOT to use `git absorb --and-rebase`

Absorb works great for normal chains. It **breaks down** when many commits modify the **same file** — each fixup squashed into an earlier commit changes the file state that later commits' diffs were computed against, cascading into large merge conflicts.

**Pragmatic alternatives**:

1. **Single fix commit at the leaf** — loses per-PR attribution but avoids rebase deadlock. The leaf PR goes green; intermediate PRs may stay red on the same checks.

2. **Per-PR fix commits at each branch tip** — checkout each failing branch, apply just the subset of fixes relevant to that branch, commit, push. No restacking needed since each fix is independent. This is the right call when each PR needs independently green CI.

If you go with option 2, the per-PR subset is usually obvious from the failure logs: each CI failure points at a file last touched in that PR or an ancestor.

---

| Task | Command |
|---|---|
| Enable rerere (do once) | `git config --global rerere.enabled true && git config --global rerere.autoUpdate false` |
| Restack linear stack | `git checkout <top> && git rebase <changed-base>` |
| Restack tree-shaped stack | `for leaf in $(find_leaves ...); do git checkout "$leaf" && git rebase <base>; done` |
| Sync stack onto updated main | `git checkout <top> && git rebase main` |
| Absorb fix into right commit | `git add -A && git absorb --base <stack-bottom> --force-author --and-rebase` |
| Absorb dry run | `git add -A && git absorb --base <stack-bottom> --dry-run` |
| Non-interactive autosquash | `GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash <base>` |
| Non-interactive rebase continue | `GIT_EDITOR=true git rebase --continue` |
| Batch push stack | `walk_stack "owner/repo" "<root>" \| tail -n +2 \| xargs git push --force-with-lease origin` |
| Find bottom of stack | `gh pr list --base main --search "head:<prefix>" --state open --json number,headRefName` |
| Walk full stack tree | `walk_stack "owner/repo" "<bottom-branch>"` |
| Find leaf branches | `find_leaves "owner/repo" "<bottom-branch>"` |
| Trace stack with metadata | `trace_stack "owner/repo" "<bottom-branch>" \| column -t -s $'\t'` |
| Normalize CI status | `[.statusCheckRollup[] \| (.conclusion // .state // .status // "PENDING")]` |
| Merge stack (scripted) | `merge_stack "owner/repo" 101 102 103` |
| Find stray conflict markers | `git grep -nE '^(<<<<<<<\|>>>>>>>\|=======$)'` |
| Drop a duplicate commit | `GIT_EDITOR=true GIT_SEQUENCE_EDITOR='sed -i.bak -E "s/^pick <SHA>[a-f0-9]*/drop <SHA>/"' git rebase -i --update-refs <base>` |
| Recover from generated-file conflict | `git checkout HEAD -- <file> && git update-index --refresh && GIT_EDITOR=true git rebase --continue` |
| Verify content matches origin (post-rebase) | `diff <(git show origin/<branch>:<file>) <(git show <branch>:<file>)` |
