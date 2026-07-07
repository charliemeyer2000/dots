#!/usr/bin/env python3
"""GIF fallback for when no browser session is available; prefer native upload
(references/embedding.md), which yields a real player and needs no branch.

Uploads assets to a branch via the Contents API and prints their raw URLs. A GIF
referenced as https://github.com/{owner}/{repo}/raw/{branch}/{path} renders inline
(animated), even in private repos; a committed mp4 does NOT render as a player.
Prefer --branch <the PR branch> so the asset merges to the default branch; a
dedicated pr-<N>-demo-assets branch also works but must never be deleted. Branch
names must be slash-free.

Usage: python upload_pr_asset.py --repo OWNER/NAME --branch BRANCH LOCAL:REPO_PATH...
Auth comes from `gh auth token`.
"""
import argparse, base64, json, subprocess, sys, urllib.error, urllib.request

API = "https://api.github.com"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="OWNER/NAME")
    ap.add_argument("--branch", required=True, help="slash-free branch name")
    ap.add_argument("--base", default="main", help="branch to fork from (default: main)")
    ap.add_argument("files", nargs="+", help="LOCAL_PATH:REPO_PATH pairs")
    a = ap.parse_args()

    if "/" in a.branch:
        sys.exit("branch name must not contain '/' (breaks raw-URL ref resolution)")
    owner, name = a.repo.split("/", 1)
    token = subprocess.check_output(["gh", "auth", "token"]).decode().strip()
    hdr = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
    }

    def call(method, path, body=None):
        url = path if path.startswith("http") else f"{API}{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, headers=hdr, method=method)
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.load(r)
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read().decode() or "{}")

    st, ref = call("GET", f"/repos/{owner}/{name}/git/ref/heads/{a.base}")
    if st != 200:
        sys.exit(f"could not read base branch {a.base}: {st} {ref}")
    sha = ref["object"]["sha"]

    st, res = call("POST", f"/repos/{owner}/{name}/git/refs",
                   {"ref": f"refs/heads/{a.branch}", "sha": sha})
    if st == 422:
        print(f"branch {a.branch}: exists", file=sys.stderr)
    elif st == 201:
        print(f"branch {a.branch}: created", file=sys.stderr)
    else:  # genuine failure (403/404/500/…) — don't barrel into uploads
        sys.exit(f"failed to create branch {a.branch}: {st} {res}")

    urls = []
    for pair in a.files:
        local, repopath = pair.split(":", 1)
        with open(local, "rb") as f:
            content = base64.b64encode(f.read()).decode()
        st, cur = call("GET", f"/repos/{owner}/{name}/contents/{repopath}?ref={a.branch}")
        body = {"message": f"chore(demo): add {repopath}", "content": content, "branch": a.branch}
        if st == 200 and isinstance(cur, dict) and cur.get("sha"):
            body["sha"] = cur["sha"]  # update in place if re-running
        st, res = call("PUT", f"/repos/{owner}/{name}/contents/{repopath}", body)
        if st not in (200, 201):
            sys.exit(f"upload failed for {repopath}: {st} {res}")
        url = f"https://github.com/{owner}/{name}/raw/{a.branch}/{repopath}"
        urls.append(url)
        print(f"uploaded {repopath}: {st}", file=sys.stderr)

    for u in urls:
        print(u)


if __name__ == "__main__":
    main()
