---
name: skill-finder
description: Discover agent skills from the open skills.sh ecosystem and install them the dots way — vendored into this repo and committed, never imperatively. Use when the user asks "how do I do X", "find a skill for X", "is there a skill for X", "can you do X", wants to add/install a new skill, or wants to extend agent capabilities.
---

# Skill Finder

Custom skill for this dotfiles repo. It covers how to **discover** skills from the
open agent-skills ecosystem and **install** them so they stay managed by the dots
repo (committed to git, synced to every machine on rebuild).

## When to Use This Skill

- The user asks "how do I do X" where X might be a common task with an existing skill
- "find a skill for X" / "is there a skill for X" / "can you do X"
- The user wants to add, install, or vendor a new skill
- The user wants to extend agent capabilities, or wishes they had help with a domain
  (design, testing, deployment, etc.)

## How skills are managed here (READ FIRST)

Skills on this machine are **owned by the dots repo**, not by the `npx skills` CLI.
The source of truth is `config/agents/skills/` in the dots repo. home-manager
deploys it to `~/.agents/skills/`, which every agent reads via symlinks
(`~/.claude/skills`, `~/.config/devin/skills`).

Consequences:

- **Discovery** with `npx skills find` is fine — it is read-only and writes nothing.
- **Installation** must go through `just skill-add`, which copies the skill into
  `config/agents/skills/<name>/` so it is committed and synced to every machine.
- **NEVER run `npx skills add`** (or `-g`). It drops unmanaged files into
  `~/.agents/skills/` plus an entry in `~/.agents/.skill-lock.json`, bypassing the
  repo. Those files aren't committed, never reach the other machines, are invisible
  to home-manager, and rot. Every skill must live in `config/agents/skills/`.

## Step 1 — Understand what they need

Identify the domain (React, testing, design, …), the specific task (writing tests,
reviewing PRs, …), and whether it's common enough that a skill likely exists.

## Step 2 — Discover (read-only)

```bash
npx skills find [query] [--owner <owner>]
```

Examples:

- "make my React app faster" → `npx skills find react performance`
- "help with PR reviews" → `npx skills find pr review`
- "create a changelog" → `npx skills find changelog`

Results print in `owner/repo@skill` form:

```
Install with npx skills add <owner/repo@skill>

vercel-labs/agent-skills@vercel-react-best-practices
cowork-os/cowork-os@humanizer  239 installs
```

Prefer skills with high install counts and reputable sources (`vercel-labs`,
`anthropics`, `microsoft`); be skeptical of unknown authors with few installs.

## Step 3 — Present options

Show the candidate skill(s) with: what it does, the **dots install command** from
Step 4 (never `npx skills add`), and a link to learn more at skills.sh.

## Step 4 — Install via the dots repo

Translate the `owner/repo@skill` from discovery into a `just skill-add` call by
splitting on the `@`:

```
cowork-os/cowork-os@humanizer
        └── repo ──┘ └ skill ┘
```

→ `just skill-add cowork-os/cowork-os humanizer`

Run it from the dots repo root, then rebuild to deploy:

```bash
cd "$(cat ~/.config/dots/location 2>/dev/null || echo ~/all/dots)"
just skill-add <owner/repo> <skill>
just switch <config>   # e.g. darwin-personal — see the fleet in AGENTS.md
```

(Interactive zsh also has a `skill-add` alias that already `cd`s into the repo, and
`just skill-install <owner/repo> <skill> <config>` does add + rebuild in one step.)

`just skill-add` clones the source repo, resolves the skill by its canonical
frontmatter `name:` (falling back to the folder name), and copies the **whole**
skill subtree — `references/`, `scripts/`, runtime-prompt files and all — into
`config/agents/skills/<name>/`. `just switch` then symlinks it into
`~/.agents/skills/` for every agent.

> Edge case: a few `npx skills find` results are URL-backed "well-known registry"
> sources rather than a GitHub `owner/repo` (their install command is
> `npx skills add <url> --skill <name>`). `just skill-add` only handles GitHub
> `owner/repo` sources — for a URL-backed source, tell the user so they can vendor
> it into `config/agents/skills/` by hand.

## Managing installed skills

From the dots repo (or the matching zsh aliases):

- `just skill-list` — list installed skills
- `just skill-search <owner/repo>` — list skills available in a GitHub repo
- `just skill-remove <skill>` — remove a skill from the repo (then `just switch`)
- `just skill-install <owner/repo> <skill> <config>` — add **and** rebuild in one step

## When no skill fits

1. Say no existing skill was found.
2. Offer to do the task directly with general capabilities.
3. If it's recurring, offer to author a new skill in
   `config/agents/skills/<name>/SKILL.md` (the `skill-creator` skill can help) so
   it's version-controlled like every other skill here.
