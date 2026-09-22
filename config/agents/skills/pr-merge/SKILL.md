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
