---
name: dueflow-gateway
description: Use the Dueflow MCP gateway (Executor) to reach any Dueflow company service — GitHub Dueflow-co, Linear, Notion, Sentry, PostHog, Vercel, Sanity, Stripe, Brex, Whop, Resend, Convex, Postgres (prod read / prod write / preview), AWS (read + admin), 1Password `dueflow-production`, Slack, Granola, Langfuse, Exa, LLM spend. Trigger whenever a task touches Dueflow data, secrets, infra, or a Dueflow SaaS account, or when the `dueflow` MCP server's `execute` / `skills` / `resume` tools appear. Covers the search → describe → call workflow inside `execute`, result shapes, approval pauses, and what is deliberately not on the gateway.
---

# Dueflow MCP gateway (Executor)

Every Dueflow company service is federated behind ONE pre-authenticated MCP server, so never do a
separate login/OAuth/API-key dance for a service the gateway carries. Access is per-user: the
gateway maps your Google identity to a tier (`super-admin` / `lead` / `engineer` / `fte`) and only
that tier's tools exist for you. If a tool "isn't found", you aren't allowed it — don't route
around the gateway with a raw token.

- Devin: the `dueflow` MCP server (`mcp_tool server="dueflow"`), signed in with Google.
- Claude Code / other MCP clients: remote MCP `https://mcp.dueflow.co/mcp` — DCR → "Continue with
  Google" (@dueflow.co) → consent. Console (catalog, users, API keys; admins only) at
  `https://mcp.dueflow.co`. (`executor.mcp.dueflow.co` is the same stack's pilot hostname; if
  `mcp.dueflow.co` still answers with flat `<service>-<tool>` tools it hasn't been cut over yet —
  use the pilot hostname.)
- Slack bot (openclawd) reaches the same gateway per-sender via `scripts/dueflow-mcp.mjs`
  (`search` / `describe` / `call` / `exec` / `resume`) — see that repo's `skills/gateway/SKILL.md`.

## The surface is NOT a flat tool list

The gateway is [Executor](https://github.com/UsefulSoftwareCo/executor): instead of ~1000
`<service>-<tool>` MCP tools, the MCP server exposes a handful of tools and you write short
TypeScript programs that call the federated tools:

| MCP tool | Use |
|---|---|
| `skills({ name: "execute" })` | Executor's own how-to for `execute` (rules + the list of integrations you can see). Call once per session before writing code. |
| `execute({ code })` | Run a TypeScript program in the sandbox. This is where all real work happens. |
| `resume({ executionId, action, content? })` | Answer an approval / form pause from `execute` (`accept` / `decline` / `cancel`; `content` is a JSON string for forms). |
| `create-artifact` / `edit-artifact` / `list-artifacts` / `show-artifact` | Saved React UI artifacts rendered in the Executor console (rarely needed from an agent). |

Federated tools are addressed `tools.<integration>.org.shared.<tool_id>` — integration is the
service name from the catalog, `tool_id` is the upstream tool name lower-snake-cased
(`github.org.shared.search_repositories`, `linear.org.shared.list_teams`,
`postgres.org.shared.execute_sql`, `aws.org.shared.call_aws`, `onepassword.org.shared.*`).

## Workflow inside `execute` (search → describe → call)

```ts
// 1. FIND — intent + key nouns; ranked, paginated, scoped to YOUR tier.
const { items, total, hasMore, nextOffset } = await tools.search({ query: "linear list issues", limit: 12 });
// narrow to one service when you know it:
//   await tools.search({ namespace: "postgres", query: "sql" })
const path = items[0]?.path;
if (!path) return "no matching tool";

// 2. DESCRIBE — exact TypeScript input/output types. Read them; don't guess arg names.
const d = await tools.describe.tool({ path });
// d.inputTypeScript, d.outputTypeScript, d.typeScriptDefinitions
// a bad path gives d.error = { code: "tool_not_found", suggestions: [...] } — use a suggestion.

// 3. CALL — the path from search/describe IS the exact key under `tools`.
const r = await tools[path]({ limit: 10 });
if (!r.ok) return r.error;                       // { code, message, status?, details?, retryable? }
return JSON.parse(r.data.content[0].text);       // most upstreams: MCP text content holding JSON
```

Keep each program small and return a compact value; filter big collections in code instead of
calling per-item tools. Multi-step work (read → decide → write) belongs in ONE program, not N
round trips. `emit(x)` streams intermediate output; `emit(result.data)` renders a `ToolFile`.

### Result shapes

- Every tool call is a union: `{ ok: true, data }` or `{ ok: false, error }`. Branch on `ok`.
- `data` is the upstream payload. For MCP-federated servers (nearly all of ours) that is MCP
  content: `data.content[0].text` is usually a JSON string of the actual answer. HTTP/OpenAPI
  tools also carry `http: { status, headers }` next to `data`.
- `execute` returns `{ status: "completed", result, content }` — `content` is what you `emit()`ed
  plus the return value.
- A gated tool (prod writes, finance) returns `status: "waiting_for_interaction"` with an
  `executionId`, the `interaction` (question / approval) and an expiry. Show it to the human, then
  `resume({ executionId, action: "accept" })` (or `decline`). An expired/unknown id comes back
  `execution_not_found` with `recovery: "re_execute"` — run the program again.

### Sandbox rules

- No `fetch`, no imports, no filesystem, no `Buffer`/`atob`/`TextDecoder`, no `setTimeout`. Only
  `tools.*`, `emit`, plain JS/TS. Type annotations are stripped (no `enum`, no decorators).
- `tools` is a lazy proxy: `Object.keys(tools)` / spread / `for…in` throw. `tools.search` is the
  index; `tools.executor.coreTools.connections.list({})` lists connections.
- Use the full dotted path via `tools[path]`; never assemble segments by hand.
- A tool call that fails with a transport error may still have run upstream. Never blindly re-run a
  program containing a write — check with a read first.

## Service notes

- **Secrets**: company secrets live in the 1Password vault `dueflow-production`, read via
  `onepassword.org.shared.*` — NOT the local `op` CLI (your service account only sees `Developer`).
  AWS Secrets Manager `dueflow/mcp-*` entries are synced FROM 1Password by dueflow-infra's
  `sync-secrets` (write to 1P first, add the `secrets-sync.json` mapping, sync).
- **AWS** (account `144711568030`, `us-east-1`): `aws.org.shared.call_aws` is the read-only role
  (super/lead/engineer); `aws-admin.org.shared.call_aws` is PowerUser and super-admin only. Both
  take `{ cli_command: "aws …" }` — a plain CLI line, no `--profile`, no `--cli-binary-format`.
- **Postgres**: `postgres` = prod read-only (lead/engineer/super), `postgres-preview` = preview,
  `postgres-prod-write` = unrestricted prod (DDL included) — super only, approval-gated. Tools:
  `execute_sql`, `list_schemas`, `list_objects`, `get_object_details`, `explain_query`, …
- **Convex**: `convex-dev` / `convex-staging` full rw; `convex-prod-read` read-only for the team;
  `convex-prod-write` (mutations/actions/env) super only.
- **Finance**: `brex` / `stripe` / `whop` reads for lead (+ engineer for stripe/whop); writes
  super only.
- **Slack**: acts as Charlie's user token → super only.
- **Granola**: `list_meetings` / `get_meeting` / `get_transcript` / `list_folders`; only notes in a
  Granola *space* are visible.
- **Not on the gateway (yet)**: `google-workspace` (Executor cannot bind the caller's identity to
  it, so it is deliberately held back — do not expect Gmail/Calendar/Drive tools) and `dub-links`
  (hosted MCP auth broken upstream). Anything else missing from `skills({name:"execute"})`'s
  integration list is a tier restriction, not an outage.
- **Who gets what** is code: `gateway-config/tiers.json` + `servers.json` in
  `Dueflow-co/dueflow-infra` (built into Executor by the `executor-catalog` workflow). Membership
  comes from the `mcp-*@dueflow.co` Google groups. Change access there, never by hand in the console.

## Anti-patterns

- Enumerating tools to "see what's there" — search by intent instead; the catalog is large.
- Guessing a path like `tools.github.search_repositories` — always `search`/`describe` first.
- Falling back to a personal token (gh, `op`, aws profile) for a Dueflow resource the gateway has.
- Treating `tool_not_found` as a bug — for a known service it is RBAC (or a held-back upstream).
