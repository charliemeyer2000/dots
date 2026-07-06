// Mint a permanent github.com/user-attachments/assets/<uuid> URL (a real inline
// <video> player, branch-free) by running GitHub's own 3-step upload (policy → S3 →
// finalize). No public API exists, so this must run in a LOGGED-IN github.com page
// that has a comment box (a <file-attachment> element) — inject via `agent-browser
// eval`. Bytes must be page-reachable: SOURCE_URL (raw.githubusercontent.com, since
// github.com/.../raw is CSP-blocked) or BASE64 for small files; for large local
// files use agent-browser's file `upload` (Method A) instead.

async () => {
  const SOURCE_URL = "https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path/demo.mp4"; // or null
  const BASE64 = null; // base64 (no "data:" prefix); used when SOURCE_URL is null
  const NAME = "demo.mp4";
  const CONTENT_TYPE = "video/mp4";

  const out = {};
  try {
    const fa = document.querySelector("file-attachment");
    if (!fa) return { error: "no <file-attachment> on page — open a comment box for the target repo" };
    const repoId = fa.dataset.uploadRepositoryId;
    const policyUrl = fa.dataset.uploadPolicyUrl || "/upload/policies/assets";
    const csrf = fa.querySelector("input.js-data-upload-policy-url-csrf")?.value;
    if (!repoId || !csrf) return { error: "missing repo id / csrf on <file-attachment>" };

    let bytes;
    if (SOURCE_URL) {
      const r = await fetch(SOURCE_URL);
      if (!r.ok) return { error: `source fetch ${r.status} (use raw.githubusercontent.com, not github.com/raw)` };
      bytes = await r.arrayBuffer();
    } else if (BASE64) {
      bytes = Uint8Array.from(atob(BASE64), (c) => c.charCodeAt(0)).buffer;
    } else {
      return { error: "set SOURCE_URL or BASE64" };
    }
    const file = new File([bytes], NAME, { type: CONTENT_TYPE });
    out.fileSize = file.size;

    // 1) policy
    const pf = new FormData();
    pf.append("name", file.name);
    pf.append("size", String(file.size));
    pf.append("content_type", file.type);
    pf.append("authenticity_token", csrf);
    pf.append("repository_id", repoId);
    const pol = await fetch(policyUrl, {
      method: "POST", body: pf, credentials: "include",
      headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
    });
    out.policyStatus = pol.status;
    const polText = await pol.text();
    let policy;
    try { policy = JSON.parse(polText); } catch { out.policyBody = polText.slice(0, 200); return out; }
    out.href = policy.asset && policy.asset.href;

    // 2) S3 upload (form fields first, file last)
    const uf = new FormData();
    Object.entries(policy.form).forEach(([k, v]) => uf.append(k, v));
    uf.append("file", file);
    const up = await fetch(policy.upload_url, { method: "POST", body: uf });
    out.s3Status = up.status;

    // 3) finalize (without this the href 404s)
    const ff = new FormData();
    ff.append("authenticity_token", policy.asset_upload_authenticity_token);
    const fin = await fetch(policy.asset_upload_url, {
      method: "PUT", body: ff, credentials: "include", headers: { Accept: "application/json" },
    });
    out.finalizeStatus = fin.status;
    return out; // { href, policyStatus:201, s3Status:204, finalizeStatus:200 }
  } catch (e) {
    out.error = String(e);
    return out;
  }
};
