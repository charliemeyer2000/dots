---
name: tracking-doc
description: >-
  Create and maintain a long-lived tracking doc (progress doc, build doc, worklog, artifact,
  dossier) so work survives across sessions, context compactions, and machines. Trigger when
  starting or resuming substantial multi-session work — a large feature, migration, multi-PR/
  changelist stack, or deep investigation — or when the user mentions a tracking/progress doc,
  worklog, scratchpad, or "keep notes as you go," or wants to avoid losing context across
  compactions. NOT for user-facing docs (READMEs, API guides) or build/CI artifacts.
---

# Tracking Doc

Durable memory for work that outlives one session. Core principle: **record decisions, facts, and
state — not a transcript.** Write so a fresh agent with zero context can resume tomorrow without
re-deriving what you worked out.

## When to create one

Only when continuity is at stake — any of: spans more than one session or a compaction; a
dependent stack to land in order; understanding cost (or will cost) a lot of context to rebuild;
another agent/machine/person continues it; open decisions await a human. Otherwise skip it — the
PR description is the artifact. Start one mid-stream the moment work outgrows a session.

## Where it lives

Never committed — put it where git won't stage it:

- Default `<repo>/.agents/local/<work>.md`. Ensure ignored on first use:
  `git check-ignore -q .agents/local/ || echo '.agents/local/' >> "$(git rev-parse --git-dir)/info/exclude"`
- Spans multiple worktrees: `~/.local/state/agent-tracking/<repo>/<work>.md`, outside any repo.

Reference the path from the PR/change description so the next session finds it.

## Stacks: one worktree

Keep a dependent stack (`A→B→C`, each its own PR) in one worktree; `git switch` between branches,
restack with `git rebase --update-refs`. Don't split a stack across worktrees — a branch checks
out in only one, and restacking rewrites the upper branches. The doc in `.agents/local/` survives
every switch and rebase (ignored files are untouched), so it's the stack's fixed anchor; its
"Change / PR stack" tier is the live map.

## Structure: rigid spine, flexible ribs

Order by volatility — volatile on top (read first), stable middle, append-only history bottom.
Keep this order:

1. **Goal** — one paragraph; what done looks like.
2. **Status / Next** — current state + the next action. Rewrite freely; read first on resume.
3. **Open questions** — blocked on a human or missing info; delete when answered.
4. **Decisions (locked)** — settled; don't re-litigate.
5. **Key facts / map** — expensive understanding distilled: how pieces fit, load-bearing code as
   `path:line`, gotchas, dated. The compression that saves a future session.
6. **Plan** — steps with status markers (`[ ]` / `[~]` / `[x]`).
7. **Change / PR stack** — if stacked: each branch → change → base → CI/review, in landing order.
8. **Worklog** — append-only, newest first, dated; one line per unit. Never rewrite.
9. **Decision log** — append-only: decision + why, dated. (Fold into Decisions for a light doc.)

Within the stable tiers, add or drop feature-specific sections freely.

## What goes in, what stays out

Test each line: would a fresh agent need this to avoid re-deriving something expensive or
repeating a mistake? If no, cut it.

- **In**: decisions + why; expensive-to-establish facts (`path:line`, dated); current state + next
  action; open questions.
- **Out**: pasted code/output (link instead — copies drift); routine narration; anything
  reconstructable from `git log` / the PR / the code; speculation.

Reads like a transcript → too much. A fresh agent would re-decide something you settled → too
little; add the conclusion, not the journey.

> Too much: "grepped for the handler, found 3 — first a mock, second deprecated, third in
> session.ts is real, it calls validateToken which..."
> Better: "Auth entry: `src/auth/session.ts:42` (`validateToken`). `legacy.ts` handler is
> deprecated — ignore."

> Too little: "Decided on the schema."
> Better: "Schema: `expiresAt` as epoch ms, not ISO — client clock-skews on ISO parse (incident
> 2025-05-03). Locked."

## Cadence

- Read tiers 1–4 at session start and after any compaction — that's the resume payload.
- Update in small increments after each unit (decision, fact, phase, PR). Don't batch to session
  end; a killed or compacted session loses unwritten updates.
- Flush Status/Next before stopping or when context runs low.

## How rigid

Spine order is a contract so any agent knows where to look; sections within tiers are yours to
shape. Drop tiers that don't apply. If a rule fights the work, the work wins.

## Template

```markdown
# <Work name> — Tracking Doc

## Goal
<One paragraph: what "done" looks like.>

## Status / Next
<Where things stand. The single most important next action.>

## Open questions
- [ ] <Blocked on a human / missing info.>

## Decisions (locked)
- <Settled choice> — <one-line why>. (<date>)

## Key facts / map
- <Expensive fact, with `path:line`>. (<date>)

## Plan
- [x] <done>  · [~] <in progress>  · [ ] <todo>

## Change / PR stack   (only if stacked)
1. <branch> → <#PR>, base <base> — <CI/review state>

## Worklog   (append-only, newest first)
- <date> — <one line: what changed / what was learned>.

## Decision log   (append-only)
- <date> — <decision> because <why>.
```
