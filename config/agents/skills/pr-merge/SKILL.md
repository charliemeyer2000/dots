---
name: pr-merge
description: Merge a GitHub PR as Charlie (charliemeyer2000) with his personal PAT via the GraphQL API. Use only when Charlie explicitly says to merge a PR in his own repos (charliemeyer2000/*), or invokes this skill.
---

# Merge a PR as Charlie

Invoking this skill is Charlie's approval: the PR he named gets merged with his PAT from
`op://Developer/GitHub/credential`, which acts as `charliemeyer2000` (admin on his repos, so
branch rulesets that require PRs/`ci` still apply but his bypass does). The default git token in
Devin sessions is the `devin-ai-integration[bot]` install token and can't merge.

Rules: only repos Charlie owns (`charliemeyer2000/*`) — never Dueflow (that has its own PAT and
flow). One PR per invocation unless he listed several. Check CI is green and the PR is mergeable
first (`git_pr_checks` / `git_view_pr`); don't merge over a red check. Remember that in
`life-infra`, merging is deploying. The token stays in a shell variable — never print, log, or
write it to disk, never pass it as a CLI arg.

```bash
export GH_TOKEN="$(op read op://Developer/GitHub/credential)"
PR_ID=$(gh api graphql -f o=charliemeyer2000 -f r=<repo> -F n=<number> \
  -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){id}}}' \
  --jq .data.repository.pullRequest.id)
gh api graphql -f id="$PR_ID" -f m=SQUASH \
  -f query='mutation($id:ID!,$m:PullRequestMergeMethod!){mergePullRequest(input:{pullRequestId:$id,mergeMethod:$m}){pullRequest{number merged state}}}'
unset GH_TOKEN
```

`SQUASH` is the default for his repos; use `MERGE` only if he asks. Delete the head branch
afterwards only if he asks (`gh api -X DELETE repos/charliemeyer2000/<repo>/git/refs/heads/<branch>`
with the same `GH_TOKEN`). Afterwards, verify with `git_view_pr` and report the merge commit.

## Merging a stack

When he says "merge the stack", use GitHub's native stacked PRs (public preview, API version
`2026-03-10`) instead of merging one PR at a time: one call on the *top* PR squash-merges every
PR below it, bottom-up, each as its own commit, and fires one CI/deploy run for the whole stack.
Read the `pr-stacking` skill for the git side (restack, `--update-refs`, force-with-lease).

1. Is it a stack GitHub knows about? `gh api repos/charliemeyer2000/<repo>/pulls/<top> --jq .stack`
   (`id`, `position`, `size`, `base`). A dependency-linked chain that isn't registered can be:
   `POST /repos/charliemeyer2000/<repo>/stacks` with `{"pull_requests":[bottom,…,top]}` (each
   base must equal the previous head). PRs based on `main` that aren't in the chain are merged
   separately, first, if the stack depends on them.
2. Every PR in the stack must be green and mergeable (`git_pr_checks`, `mergeable_state: clean`);
   `merge-async` refuses otherwise.
3. Merge from the top:

   ```bash
   TOK="$(op read op://Developer/GitHub/credential)"
   api() { curl -sS -H @<(printf 'Authorization: Bearer %s\n' "$TOK") \
     -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2026-03-10" "$@"; }
   api -X PUT "https://api.github.com/repos/charliemeyer2000/<repo>/pulls/<top>/merge-async" \
     -d '{"merge_method":"squash","merge_action":"direct_merge","expected_head_sha":"<top head sha>"}'
   # → {"status":"pending","details":{"uuid":…}}; poll until it leaves "pending":
   api "https://api.github.com/repos/charliemeyer2000/<repo>/pulls/<top>/merge-async/<uuid>"
   unset TOK
   ```

   `curl` with the header from a process substitution, not `gh api`: in Devin sessions `gh` is a
   wrapper that keeps the bot install token even with `GH_TOKEN` set, and `merge-async` on a
   stack needs Charlie's PAT.
4. `{"status":"failed","details":{"message":"Merge conflict detected"}}` means the stack isn't
   linear on top of trunk (the "Rebase stack" button state) — `main` moved since the stack's
   base. Restack locally from the leaf (`git rebase --update-refs origin/main`), resolve, verify
   each PR's diff is unchanged, `git push --force-with-lease` all branches, wait one CI cycle,
   retry step 3. A chain whose branch tips are *merge commits* (a child merged its parent branch
   back in) can't be linearized by `--update-refs` alone: rebuild it bottom-up with `git checkout
   -B <branch> <parent> && git cherry-pick <that PR's own commits>`, then push.
5. Verify: every PR in the stack `merged=true`, `git log origin/main` shows one squash commit per
   PR in stack order, then watch the single post-merge workflow run (`life-infra`: deploy /
   terraform).

Auto-merge is not supported for stacked PRs; merge queues are.
