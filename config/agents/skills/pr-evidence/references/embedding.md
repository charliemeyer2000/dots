# Embedding PR media natively — mechanics & why

Verified against live PRs. A `github.com/user-attachments/assets/<uuid>` URL renders
any media inline (image, GIF, or a real video player), is permanent, and needs no
branch — but it has **no public API**; it's minted only by an authenticated web upload,
so a `gh` token alone can't. Images/GIFs have a pure-`gh` fallback (commit + `raw`);
video has none — convert to a GIF.

## What renders

| Method | png/gif | real `<video>` | private | permanent | branch-free | no browser |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| **Native upload → `user-attachments`** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Commit png/gif + `…/raw/…` | ✅ | — | ✅ | while ref lives | ❌ | ✅ |
| Commit **mp4** + `raw` / `blob?raw=true` | — | ❌ link only | ✅ | — | ❌ | ✅ |
| `<video>` / `<img>` tag, repo `src` | — | ❌ stripped | — | — | — | — |
| `raw.githubusercontent.com` (private) | ❌ 404 | ❌ | ❌ | ✅ | ❌ | ✅ |

A committed **mp4** is served `application/octet-stream`, so browsers won't play it
inline and `<video>` tags get sanitized out — a dangling asset branch buys nothing and
rots when branch-cleanup runs. Only `user-attachments` gives a real player.

## Native upload (default; png/gif/mp4)

Passkey/2FA/SSO can't be scripted, so log in once with
[../scripts/github-login.sh](../scripts/github-login.sh) — it saves a session to
`~/.agent-browser/pr-evidence-github.state.json`, reused across runs (re-run when it
expires). Then, in an isolated session:

```bash
STATE="$HOME/.agent-browser/pr-evidence-github.state.json"
S="agent-browser --session $AGENT_BROWSER_SESSION"
$S --state "$STATE" open "https://github.com/OWNER/REPO/pull/<N>" && $S wait --load networkidle
$S eval "document.querySelector('meta[name=user-login]')?.content || ''"   # empty ⇒ no login → fallback
$S upload "#fc-new_comment_field" /tmp/after.png            # selector first, then file (png/gif/mp4)
$S eval "document.querySelector('#new_comment_field').value"   # poll → https://github.com/user-attachments/assets/<uuid>
$S eval "document.querySelector('#new_comment_field').value=''"   # clear; don't submit
```

`--state` restores the login into a fresh session (cross-session restore is verified).
`gh pr edit` the URL(s) into the body — a table for before/after images, a bare URL on
its own line for a video. (Under the hood `upload` performs GitHub's private
policy→S3→finalize handshake; the repo id + CSRF token sit on the page's
`<file-attachment>` element if you ever need to reproduce it by hand.)

## Fallback: commit + raw (images & GIF; no login)

[../scripts/upload_pr_asset.py](../scripts/upload_pr_asset.py) base64-uploads via the
Contents API (handling the ARG_MAX limit of `gh api -f content=…`) and prints `raw`
URLs. Committed PNG/GIF render inline (GIFs animate) even in private repos; mp4 doesn't.
The uploader needs a **slash-free** branch, so either a dedicated `pr-<N>-evidence`
branch (never delete it) or commit to the PR branch and reference by commit-SHA
permalink (slash-free, permanent, merges to main).

## Verify

Load the PR and confirm the media is really there:

```js
() => { const b = document.querySelector('.comment-body,.markdown-body');
  return { imgs: b.querySelectorAll('img[src*="user-attachments"]').length,
           videos: b.querySelectorAll('video').length }; }
```

For a committed image/GIF: `gh api -X POST /markdown -f mode=gfm -f context=OWNER/REPO
-f text='![d](<raw-url>)'` → `src` must stay on `github.com` (a GIF carries
`data-animated-image`), proving it isn't camo-proxied (which 404s on private repos).

## Credits

`dueflow-feature` (Contents-API uploader), `everyinc/feature-video` (agent-browser
native upload), `github/awesome-copilot` (method matrix).
