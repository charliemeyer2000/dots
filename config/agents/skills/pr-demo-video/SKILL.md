---
name: pr-demo-video
description: >-
  Record a short screen demo of a UI feature and embed it INLINE in a GitHub pull
  request description — a real HTML5 video player, hosted natively by GitHub, no
  third-party host and no fragile dangling branches. Use whenever the user wants to
  "add a video to the PR", "record a demo", "show the feature in the PR", "demo
  video", "feature video", "screen recording for the PR", or attach visual proof of
  a UI change to a pull request. Covers the whole pipeline: record (agent-browser)
  → process (ffmpeg, 2× speed) → embed (native user-attachments upload; GIF
  fallback for headless) → verify it actually renders.
---

# PR Demo Video

Goal: a short (~2× speed) screen recording of a feature working, embedded **inline
in the PR description** so reviewers watch it without leaving GitHub, hosted by
GitHub itself (no Loom/UploadThing/S3), done **autonomously**.

Three stages: **record → process → embed**. The embed stage has all the sharp
edges — read [references/embedding.md](references/embedding.md) before you touch
it; it explains *why* only one method yields a real player and documents the exact,
verified commands.

## The one decision that matters

| | Default: **native upload** | Fallback: **GIF** |
|---|---|---|
| Result | real `<video>` player (audio + scrubbing) | inline animated GIF (no audio) |
| Hosted at | `github.com/user-attachments/assets/…` | `github.com/OWNER/REPO/raw/…` |
| Branch? | **none** — nothing to prune, ever | a committed asset (see fallback notes) |
| Needs | a logged-in browser (you're recording in one anyway) | just a `gh` token — works headless |
| Permanent? | yes | yes, as long as the ref survives |

**Default to native upload.** Only fall back to GIF when there is no browser session
available (pure CI / headless). Never use a throwaway "dangling branch" for the mp4
— see [references/embedding.md](references/embedding.md#what-does-not-work).

## Stage 1 — Record (agent-browser)

Use the **`agent-browser`** skill (Vercel Labs CLI) — it's the dots standard for
driving a browser (there is no chrome MCP), records video natively, and chains in
one shell call. The dots install it on switch (Homebrew on darwin, the llm-agents
nix overlay on Linux); if it's somehow not on PATH, `npm i -g agent-browser@latest`.
Run `agent-browser install` once per machine to fetch Chrome (auto-detects existing
Chrome/Brave). Then load the version-matched guide: `agent-browser skills get core`.
Prereqs: the app is running (e.g. `localhost:3000`) and you know the account + URL to
demo.

**Isolate the session** so parallel agents on this machine don't share one browser —
shared tabs, cookies, and (worst of all) a shared *recording* collide. Derive a unique
id once and reuse it for every command:

```bash
export AGENT_BROWSER_SESSION="$(agent-browser session id --scope worktree --prefix pr-demo-video)"
S="agent-browser --session $AGENT_BROWSER_SESSION"
```

`--scope worktree` isolates per checkout; add a unique suffix (e.g. the PR number) if
this skill might run twice in the same checkout at once. Never use the default session.

What matters for a clean take:
- **Log in once, save state** (`$S state save …`) and record in the *same*
  authenticated session, so you don't log in on camera.
- **Run the whole recorded flow in ONE chained bash call** (`&&` between steps).
  Gaps *between* separate tool calls freeze as dead frames — recording captures
  wall-clock time. End with `; $S record stop` (`;` so stop runs even on failure).
- **Pace for a 2× viewer**: insert `$S wait 800..2000` between actions.
- **Semantic locators** (`find text "…" click`, `find placeholder "…" fill "…"`) —
  `@eN` refs reset after navigation and break the take.
- **Show the actual win**: demo the positive behavior *and*, where relevant, the
  thing that used to break.

```bash
URL="http://localhost:3000/<feature-page>"
$S record start /tmp/demo.webm \
 && $S open "$URL" && $S wait --load networkidle && $S wait 2000 \
 && $S find placeholder "Search" fill "<term>" && $S wait 2000 \
 && echo FLOW_OK
$S record stop
```

## Stage 2 — Process (ffmpeg, 2×)

Make a 2× **mp4** (the deliverable) and a 2× **gif** (the fallback / thumbnail).
`setpts=0.5*PTS` doubles speed.

```bash
# 2x mp4 — web-optimized, the native-upload payload
ffmpeg -y -loglevel error -i /tmp/demo.webm -filter:v "setpts=0.5*PTS" -an \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart -crf 22 /tmp/demo-2x.mp4

# 2x gif — palette for quality; ~1000px wide, ~14fps keeps size reasonable
ffmpeg -y -loglevel error -i /tmp/demo.webm -filter_complex \
  "[0:v]setpts=0.5*PTS,fps=14,scale=1000:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
  /tmp/demo-2x.gif
```

**Verify before publishing** — extract a couple of frames and actually look at them
(a file existing ≠ it shows the right thing):

```bash
ffmpeg -y -loglevel error -ss 1.0 -i /tmp/demo-2x.mp4 -frames:v 1 /tmp/frame-a.png
ffmpeg -y -loglevel error -sseof -1 -i /tmp/demo-2x.mp4 -frames:v 1 /tmp/frame-b.png
# then Read the PNGs to confirm the feature is visible
```

## Stage 3 — Embed

Full mechanics + the *why* live in **[references/embedding.md](references/embedding.md)**.
Short version:

**Default — native upload (branch-free, real player).** In a logged-in GitHub
browser session, put the local mp4 onto the PR comment box's file input; GitHub
uploads it and hands back a `github.com/user-attachments/assets/<uuid>` URL. Extract
it, **don't submit the comment**, and drop the bare URL on its own line in the PR
description:

```bash
gh pr edit <N> --body-file <updated-body.md>
```

```markdown
## Demo (2× speed)

https://github.com/user-attachments/assets/<uuid>
```

**Fallback — GIF (headless / no browser).** Commit the GIF via the Contents API and
reference it with a `raw` URL (see the script's header for the durability rule):

```bash
python3 scripts/upload_pr_asset.py --repo OWNER/REPO --branch pr-<N>-demo-assets \
  /tmp/demo-2x.gif:demos/<feature>.gif
# → prints https://github.com/OWNER/REPO/raw/pr-<N>-demo-assets/demos/<feature>.gif
```

```markdown
![<feature> demo — 2×](https://github.com/OWNER/REPO/raw/pr-<N>-demo-assets/demos/<feature>.gif)
```

## Stage 4 — Verify it actually renders

Don't trust that markdown "should" work — confirm it:
- **Native mp4**: load the PR in the browser and assert exactly one `<video>` with
  `controls` appears in the comment body (`agent-browser eval`). See
  [references/embedding.md](references/embedding.md#verify).
- **GIF**: `gh api -X POST /markdown -f mode=gfm -f context=OWNER/REPO -f text='![d](<raw-url>)'`
  → the output must keep `src="https://github.com/…/raw/…"` and be tagged
  `data-animated-image`.

## What does NOT work — don't waste time

Committing an **mp4** to a branch and linking it (`/raw/…`, `blob?raw=true`,
`raw.githubusercontent.com`) → renders as a dead **link**, never a player (served
`application/octet-stream`). `<video>` tags are **stripped** from PR bodies. Release
assets and `raw.githubusercontent.com` don't render inline in private repos. The
*only* real player is a `user-attachments/assets/…` URL. Full detail + evidence in
[references/embedding.md](references/embedding.md).
