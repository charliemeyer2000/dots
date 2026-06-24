---
name: tracking-doc
description: >-
  Create and maintain a long-lived internal tracking doc (a.k.a. progress doc, build doc,
  worklog, artifact, or dossier) so work survives across many agent sessions, context
  compactions, machines, and runtimes. Use this whenever you start or resume substantial work
  that won't finish in one session — a large feature, a migration, a multi-PR/changelist stack,
  a deep investigation, or anything where a future session (or a different agent on a different
  machine) must pick up where this one left off without re-deriving everything. Also use it when
  the user mentions a tracking doc, progress doc, build doc, worklog, scratchpad, or "keep notes
  as you go," or asks how to stop losing context across compactions or hand work off between
  sessions. This is for the agent's/team's own working memory, NOT user-facing documentation
  (READMEs, API docs, guides) and NOT build/CI artifacts — don't trigger for those.
---

# Tracking Doc

A tracking doc is the durable memory for a piece of work. The session that holds the context
is disposable — it ends, it compacts, it moves to another machine. The tracking doc is what
persists. Its job is to let a competent agent with zero prior context resume the work tomorrow
without re-deriving what you already worked out.

The core principle, which resolves almost every question below: **a tracking doc records
decisions, facts, and state — not a transcript.**

## When to create one (and when not to)

A tracking doc costs maintenance and carries a stale-doc risk. Only pay for it when continuity
is actually at stake. Create one when **any** of these is true:

- The work will plausibly span more than one session, or hit a context compaction.
- There's a stack of dependent changes (PRs / changelists / patches) to track and land in order.
- Building the understanding took, or will take, a large chunk of context — and rebuilding it
  from scratch each session would be painful.
- A different agent, machine, or person will continue the work.
- There are open decisions waiting on a human that won't resolve immediately.

If the work fits comfortably in one session, **skip it** — the PR/change description is your
artifact. A tracking doc for a 20-minute task is pure overhead and will rot. Bias toward *not*
creating one until the work proves it needs continuity. It's perfectly fine to start one
mid-stream the moment you realize "this is bigger than one session."

## Where it lives, and how the next session finds it

- **Default: a markdown file committed in the repo.** That is what makes continuity work across
  machines and runtimes — anyone who clones the repo (you on another laptop, a cloud agent, a
  teammate) gets the doc for free. This is usually the right choice.
- **If committing a working doc isn't appropriate** (it'd be noise in a shared repo, or against
  team norms), keep it gitignored in the repo or in a sidecar location. Accept that you then lose
  the cross-machine handoff, so prefer committed when you reasonably can.
- **Name it predictably and greppably** so a fresh session finds it without being told. A good
  default is `notes/<feature>.md` or `<FEATURE>_TRACKING.md` at the repo root. Consistency
  matters more than the exact choice.
- **Make it discoverable.** A doc nobody can find is worthless. Link its path from the PR/change
  description, and if the repo has an `AGENTS.md`/`CLAUDE.md`, drop a one-line pointer there. The
  first thing a resuming session should do is look for the doc.

## Structure: rigid spine, flexible ribs

Order sections by how fast they change: **volatile at the top, stable reference in the middle,
append-only history at the bottom.** A resuming agent should learn "where are we, what's next,
what's decided" in the first screen, without scrolling through history to find it.

The **spine** — keep this order, because the predictability is the value:

1. **Goal** — one paragraph. What "done" looks like. Rarely changes; anchors everyone.
2. **Status / Next** — the current state and the single most important next action. Rewrite this
   freely; it's the first thing the next session reads.
3. **Open questions** — decisions blocked on a human, or on information you don't have yet.
   Delete each as it's answered (its answer moves down to Decisions).
4. **Decisions (locked)** — settled choices. The point of writing them down is to *stop
   re-litigating them*: if it's here, don't reopen it without a real reason.
5. **Key facts / map** — the expensive understanding, distilled: how the relevant pieces fit,
   where the load-bearing code is (as `path:line` references, not pasted code), constraints and
   gotchas you discovered, each with a date. This tier is the compression that saves a future
   session from burning its whole context rebuilding the mental model.
6. **Plan** — the steps or phases, each with a visible status marker (e.g. `[ ]` todo /
   `[~]` in progress / `[x]` done) so progress is readable at a glance.
7. **Change / PR stack** — only if the work is a stack: each branch/change, its base, and its
   CI/review state, listed in landing order.
8. **Worklog** — append-only, newest first, dated. One short entry per meaningful unit of work.
   This is narrative history; never rewrite it.
9. **Decision log** — append-only: each decision and the *why*, dated. (Distinct from
   "Decisions (locked)", which is the current settled set; this is the history of how you got
   there. In a lighter doc, fold the two together.)

The **ribs**: within the stable tiers, add, rename, or drop feature-specific sections freely — an
inventory, a data model, an API contract, a runbook, a glossary, whatever *this* work needs.

## What to write — and what to leave out

Write the doc for a competent agent with zero prior context who must continue the work tomorrow.
The test for any line: **"Would a fresh agent need this to avoid re-deriving something expensive,
or repeating a mistake?"** If no, cut it.

**Put in:**
- Decisions and the reasoning behind them (so they aren't reopened).
- Facts that were expensive to establish — architecture, constraints, "X doesn't work because Y" —
  with `path:line` refs and dates.
- The current state and the next action.
- Open questions for a human.

**Leave out:**
- Pasted code or large command output — link `path:line` or the PR/run instead. The code is the
  source of truth; any copy drifts and lies.
- Step-by-step narration of routine actions. The Worklog gets one line, not a play-by-play.
- Anything trivially reconstructable from `git log`, the change list, or the code itself.
- Speculation, and restatements of the obvious.

Two symptoms to self-correct on:
- **Reads like a chat transcript → too much.** Compress to decisions / facts / state.
- **A fresh agent would re-investigate or re-decide something you already settled → too little.**
  Add the distilled conclusion (the answer, not the journey).

**Example — too much:**
> Ran grep for the auth handler, found 3 candidates, opened each — first was a test mock, second
> was deprecated, the third in `src/auth/session.ts` is the real one, then I read it and saw it
> calls validateToken which...

Better:
> Auth entry point: `src/auth/session.ts:42` (`validateToken`). The same-named handler in
> `src/auth/legacy.ts` is deprecated — ignore it.

**Example — too little:**
> Decided on the new schema.

Better:
> Schema: store `expiresAt` as epoch ms, not ISO — the client clock-skews on ISO parsing (incident
> 2025-05-03). Locked.

## Cadence: when to read, when to update

- **Read it first.** At the start of any session on this work, and immediately after any context
  compaction, read the doc — at minimum tiers 1–4 (Goal, Status, Open, Decisions). That is the
  "load to resume" payload. Skipping it is exactly how a fresh session re-treads old ground.
- **Update as you go, in small increments.** After each meaningful unit — a decision made, a fact
  established, a phase finished, a change opened or landed — make a small edit: rewrite
  Status/Next, append one Worklog line, log the decision. Do **not** batch all updates for the end
  of the session: a session can be killed or compacted before "the end," and an unwritten update
  is a lost update. The frequent small writes *are* the mechanism — they're what survives.
- **Flush before you stop, or when context runs low.** Before ending, or the moment compaction
  feels near, make sure Status/Next reflects reality so the next session resumes cleanly.

## How rigid is this

Treat the spine (the tier order) as a contract so any agent knows where to look. Treat everything
within tiers as yours to shape: add the sections the work needs, drop the tiers that don't apply
(a non-stacked task has no PR-stack section; a light doc can merge the two logs). Don't reorder or
delete the spine merely to be tidy — the predictability is what makes the doc resumable. But the
structure serves continuity, not the reverse: if a rule is actively fighting the work in front of
you, the work wins, and you note why.

## Template

Copy this, delete the tiers that don't apply, and adapt the ribs:

```markdown
# <Work name> — Tracking Doc

## Goal
<One paragraph: what "done" looks like.>

## Status / Next
<Where things stand right now. The single most important next action.>

## Open questions
- [ ] <Decision blocked on a human / missing info.>

## Decisions (locked)
- <Settled choice> — <one-line why>. (<date>)

## Key facts / map
- <Expensive-to-learn fact, with `path:line` ref>. (<date>)

## Plan
- [x] <done step>
- [~] <in-progress step>
- [ ] <todo step>

## Change / PR stack   (only if stacked)
1. <branch> → <#PR>, base <base> — <CI/review state>

## Worklog   (append-only, newest first)
- <date> — <one line: what changed / what was learned>.

## Decision log   (append-only)
- <date> — <decision> because <why>.
```
