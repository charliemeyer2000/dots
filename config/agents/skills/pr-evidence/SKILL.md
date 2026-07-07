---
name: pr-evidence
description: >-
  Attach the right visual proof of a change to a GitHub PR — a before/after
  screenshot, a GIF, or a video — rendered inline, hosted by GitHub (no third-party
  host, no dangling branches). Use when a PR touches UI or visible behavior and a
  reviewer should see it: "add a screenshot", "before/after", "show the change",
  "record a demo", "add a video/GIF to the PR", "attach visual evidence". Picks the
  lightest medium, captures it with agent-browser, and embeds it — native
  user-attachments upload by default (png/gif/mp4), commit+raw fallback for images and
  GIFs when there's no browser login.
---

# PR Evidence

Show reviewers a visible change without making them check it out. Pick the lightest
medium, capture it, embed it inline. The *why* and exact mechanics live in
[references/embedding.md](references/embedding.md).

## Pick the medium
- static / tiny change (color, spacing, copy, a new element) → before/after **screenshot**
- one short interaction (toggle, filter, hover) → **GIF**
- multi-step flow, or needs narration → **video** (mp4)

Lighter is better — a screenshot beats a video someone has to scrub.

## Capture
Drive the browser with the **agent-browser** skill (`agent-browser skills get core` for
usage; the dots install it on switch, but `pnpm add -g agent-browser` if it's missing).
Use an isolated session so parallel agents don't collide on a browser or a recording:

```bash
export AGENT_BROWSER_SESSION="$(agent-browser session id --scope worktree --prefix pr-evidence)"
```

- Screenshots: `screenshot` — grab the pre-change baseline too for before/after.
- GIF/video: `record start … record stop` in ONE chained call (gaps between separate
  calls freeze as dead frames); warm up before recording, pace for a 2× viewer, then
  ffmpeg to a 2× mp4 and/or GIF (`setpts=0.5*PTS`). Look at a frame before publishing.

## Embed
Default: a **native `user-attachments` upload** — one mechanism for png/gif/mp4, renders
inline (a real player for video), permanent, no branch. Save a GitHub session once with
`scripts/github-login.sh` (you do passkey/SSO; reused after). Then load that session
(`--state`), `upload` the file to the comment box's `#fc-new_comment_field`, read the URL
GitHub drops into `#new_comment_field`, don't submit, and `gh pr edit` it into the body.

No browser login? **Images and GIFs** still render from a committed `raw` URL
(`scripts/upload_pr_asset.py`); a committed **mp4 never renders** — convert it to a GIF.

Then verify it actually rendered (load the PR — a video shows `<video controls>`).
Exact commands + what *doesn't* work: [references/embedding.md](references/embedding.md).
