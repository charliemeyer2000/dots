# Global Rules

## Coding Practice

- Always ultrathink about the codebase, structure, patterns, existing files/utilities. Think - what's a high-quality, senior-engineer implementation for this? 
- If you're lost, always read documentation, search the web, or consult the user for guidance.
- Read the AGENTS.md (CLAUDE.md and other agent guideline files symlink here)

## Documentation

When reading documentation, always:
- Check what version you are using to ensure the documentation you're reading aligns with the version of the package you're using. 
- When fetching, always start by searching for the `llms.txt`. If the documentation supports it, fetch the `.md` version of docs rather than the regular docs. 
- If you can't find docs, we suggest manually inspecting the installed package/tool for its generated code, or ask the user for guidance.


## Workflow

- Plan non-trivial work first: For anything 3+ steps or with architectural decisions, write the plan before touching code. If things go sideways mid-implementation, stop and re-plan — don't keep pushing.
- Verify before declaring done: Run the tests, linting, formatting, sorting, check the logs, CI, demonstrate correctness. Never mark a task complete without proof it works. Ask yourself: "would a staff engineer approve this?"
- Fix bugs autonomously: Given a bug report, failing test, or broken CI: just fix it. Point at the logs/errors and resolve them. Don't ask for hand-holding on things you can investigate yourself.
- Demand elegance, balanced: For non-trivial changes, pause and ask "is there a more elegant way?" If a fix feels hacky, reach for the clean solution. Skip this for obvious one-line fixes — don't over-engineer.
- Challenge your own work before presenting it: Diff your changes against main, sanity-check the behavior, look for what you missed.

## Core Principles

- Simplicity first: make every change as small as possible.
- No laziness: find root causes; no temporary patches or workarounds dressed up as fixes.
- Minimal impact: only touch what the task requires. Avoid drive-by edits that risk regressions. Code should always be net-positive.

## Package Managers

- JS/TS: use `pnpm`, never `npm`. node is managed by nvm, default version via nix.
- Python: use `uv` for everything. `uv run` for scripts, `uv sync` for projects, `uv tool install` for global CLI tools. never `pip install`.
- Rust: use `cargo` via `rustup`.

## Commits & PRs

- Format commit messages and PR titles as conventional commits: `<type>(<scope>): <summary>`
    - Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`
    - Scope is optional — include it when it adds clarity, omit it when the change is broad or the type alone is enough
        - With scope: `feat(zsh): add surf alias`, `chore(secrets): drop GITHUB_TOKEN auto-export`
        - Without scope: `feat: add postgresql to base packages`, `fix: VoiceInk perms`
    - When using a scope, use the package/app/module/file you're touching (e.g. `feat(dots)`, `fix(zsh)`)
    - Keep the summary concise and accurate — describe what the change does, not how
- Branches: `cm/` prefix followed by a short descriptive name (e.g. `cm/add-warp-cask`)
- Sign commits with 1Password SSH key (commit.gpgsign = true)
- If signing hangs (non-interactive context), use `git -c commit.gpgsign=false commit`
- Never add Co-Authored-By lines or any other attribution to commits or PRs

## Environment

- Config lives at `~/all/dots`
- macOS m4 pro: nix-darwin + home-manager — `just switch darwin-personal` - personal laptop
- macOS m1: nix-darwin + home-manager - `just switch darwin-agent` - always-on old mac
- Linux workstation: standalone home-manager — `just switch workstation` - linux box, 32 CPU, 5090 gpu.
- Secrets injected via 1Password `op inject` during activation

## Other machines

Check out the .ssh/config for other machines we have access to
- When connected via tailscale:
    - `workstation`: personal workstation running a 5090 
    - `jetson-nano`: edge device, jetson orin nano
- When connected to the UVA HPC cluster:
    - `uva-hpc`
