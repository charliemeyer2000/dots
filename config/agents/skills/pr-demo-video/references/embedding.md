# Embedding a demo natively — the mechanics

Everything below is verified against a live GitHub PR (see the method matrix). The
short version: **a `github.com/user-attachments/assets/<uuid>` URL is the only thing
GitHub renders as a real inline video player**, and it has **no public API** — it is
minted by an authenticated *web* upload (session cookies + a page CSRF token). A `gh`
token cannot mint one.

## Method matrix (what renders, what rots)

| Method | Real `<video>` player | Private repos | Permanent | Branch-free | API-only (no browser) |
|---|:---:|:---:|:---:|:---:|:---:|
| **Native upload → `user-attachments/assets/`** | ✅ | ✅ | ✅ | ✅ | ❌ |
| GIF via Contents API + `github.com/…/raw/` | ❌ (animated img) | ✅ | ✅ (while ref lives) | ❌ | ✅ |
| mp4 committed + `raw` / `blob?raw=true` | ❌ dead link | ✅ | — | ❌ | ✅ |
| `<video>` tag in the body | ❌ stripped | — | — | — | — |
| `raw.githubusercontent.com` mp4 | ❌ | ❌ 404 | ✅ | ❌ | ✅ |
| Release-asset mp4 | ❌ | ✅ | ✅ | ✅ | ✅ |

Only the first row is a real player. The second row (GIF) is the headless fallback.

<a id="what-does-not-work"></a>
## Why the "commit an mp4 to a branch" trick fails

GitHub serves a repo-committed mp4 as `Content-Type: application/octet-stream`, and
browsers refuse to play that inline (no content-type sniffing, by design). So a
committed-mp4 `raw` URL renders as a plain link. `<video>` tags whose `src` points
at `github.com/.../raw/...` are removed by GitHub's HTML sanitizer (only
`user-attachments` / `githubusercontent` asset srcs survive, and even those are
finicky). This is why people reach for a "dangling branch" — but for mp4 it buys you
nothing, and the orphan branch is fragile: org branch-cleanup automation or a bulk
delete removes it, the blob gets GC'd, and the embed 404s. Prefer native upload.

## Native upload — how the handshake works

GitHub's own comment box does a 3-step dance. On any repo page where you can comment,
a `<file-attachment>` element carries the two things you need:

- `data-upload-repository-id` — the numeric repo id
- a hidden `input.js-data-upload-policy-url-csrf` (`data-csrf="true"`) — the CSRF
  token for the policy request
- `data-upload-policy-url` — usually `/upload/policies/assets`

The dance (all from the logged-in page context, cookies included):

1. **POST `/upload/policies/assets`** (multipart) with `name`, `size`,
   `content_type`, `repository_id`, `authenticity_token` (the csrf above). → `201`
   with `{ upload_url, form, asset:{href}, asset_upload_url,
   asset_upload_authenticity_token }`. `asset.href` is the final
   `user-attachments/assets/<uuid>` URL.
2. **POST `upload_url`** (the S3 bucket) with every field in `form` **plus** the file
   last. → `204`.
3. **PUT `asset_upload_url`** with `authenticity_token =
   asset_upload_authenticity_token`. → `200`. Without this finalize the `href` 404s.

CSP notes (learned the hard way): from the `github.com` page, `fetch` to
`raw.githubusercontent.com` **is** allowed (use it to pull bytes for a file already
on GitHub), but `fetch` to `github.com/.../raw/...` is **blocked** (it redirects off
-origin). The S3 `upload_url` POST is allowed.

### Method A — agent-browser drives the file input (best for local files)

Idiomatic and size-independent (no base64). This is what `everyinc/feature-video`
does and what the dots standard tool is built for.

```bash
S="agent-browser --session $AGENT_BROWSER_SESSION"   # reuse the isolated recording session
$S open "https://github.com/OWNER/REPO/pull/<N>"
$S upload /tmp/demo-2x.mp4 --into "#fc-new_comment_field"   # the comment file input
# GitHub uploads and rewrites the comment textarea to contain the asset URL:
$S eval "document.querySelector('#new_comment_field').value"   # → contains https://github.com/user-attachments/assets/<uuid>
```

Extract the `user-attachments/assets/<uuid>` URL from that textarea value, **clear
the textarea without submitting** (the asset already exists on the CDN — submitting a
comment is unnecessary), then `gh pr edit <N>` to place the bare URL in the PR body.
Confirm the exact `upload`/snapshot subcommands with `agent-browser skills get core`
— don't guess flags.

### Method B — inject the handshake (deterministic; verified)

When you already have a logged-in `github.com` tab, run the handshake directly via
`agent-browser eval` (or any way to execute JS in that page's context). It's
deterministic (no waiting on GitHub's UI JS) and returns the URL. See
[../scripts/mint_user_attachment.js](../scripts/mint_user_attachment.js). Bytes must
be reachable from the page: pass a `raw.githubusercontent.com` URL for public repos,
or base64 for small files. For large local files on a private repo, prefer Method A.

## GIF fallback (headless / no browser)

Pure `gh`-token path, renders inline animated even in private repos (github.com-
hosted images load with the viewer's cookies; they aren't camo-proxied). Use
[../scripts/upload_pr_asset.py](../scripts/upload_pr_asset.py) — it forks a branch,
base64-uploads via the Contents API (handling the ARG_MAX limit that breaks a naive
`gh api -f content=…` for multi-MB files), and prints the `raw` URLs.

**Durability — avoid the orphan-branch trap.** Two options, pick per situation:
- **Into the PR's own branch** (recommended): upload to `--branch <the-PR-branch>`
  under e.g. `docs/demos/`. When the PR merges, the GIF lands on the default branch
  and is permanent — no separate branch to keep alive. Cost: the binary shows in the
  PR diff (fine for a small GIF).
- **Dedicated `pr-<N>-demo-assets` branch**: keeps the diff clean, but that branch
  **must never be deleted** (the embed URL points at it). Only do this where you
  control branch hygiene. Branch name must be **slash-free** so `raw/<branch>/<path>`
  resolves.

<a id="verify"></a>
## Verify it renders

- **Native mp4** — load the PR and assert the player exists:
  ```js
  () => { const b = document.querySelector('.comment-body, .markdown-body');
    const v = b.querySelectorAll('video');
    return { players: v.length, controls: v[0]?.hasAttribute('controls') }; }
  ```
  Expect `players: 1`, `controls: true`. The `<source>` resolves to a signed
  `private-user-images.githubusercontent.com/…?jwt=…` URL with
  `response-content-type=video/mp4` — that's normal (GitHub signs per view; the
  `user-attachments` URL in your markdown is the permanent one).
- **GIF** — `gh api -X POST /markdown -f mode=gfm -f context=OWNER/REPO -f
  text='![d](<raw-url>)'`; the output must keep `src="https://github.com/…/raw/…"`
  and carry `data-animated-image` (proves it isn't camo-proxied, which would 404 on
  a private repo).

## Credits

Distilled from `dueflow-feature` (the Contents-API GIF uploader + durability
discipline), `everyinc/compound-engineering-plugin@feature-video` (agent-browser
native upload), and `github/awesome-copilot` (the authoritative method matrix).
