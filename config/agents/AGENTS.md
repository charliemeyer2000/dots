# Global Rules

## Coding Practice

- Always **ultrathink** about the codebase, structure, patterns, existing files/utilities. Think - what's a high-quality, senior-engineer implementation for this? 
- If you're lost, always read documentation, or consult the user for guidance.
- Read the AGENTS.md (CLAUDE.md and other agent guideline files symlink here)

## Documentation

When reading documentation, always:
- Check what version you are using to ensure the documentation you're reading aligns with the version of the package you're using. 
- When fetching, always start by searching for the `llms.txt`. If the documentation supports it, fetch the `.md` version of docs rather than the regular docs. 
- If you can't find docs, we suggest manually inspecting the installed package/tool for its generated code, or ask the user for guidance.


## Package Managers

- JS/TS: use `pnpm`, never `npm`. node is managed by nvm, default version via nix.
- Python: use `uv` for everything. `uv run` for scripts, `uv sync` for projects, `uv tool install` for global CLI tools. never `pip install`.
- Rust: use `cargo` via `rustup`.

## Commits & PRs

- Format commit messages and PR titles as conventional commits: `<type>(<scope>): <summary>`
    - Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`
    - **Scope is optional** — include it when it adds clarity, omit it when the change is broad or the type alone is enough
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
- macOS: nix-darwin + home-manager — `just switch darwin-personal`
- Linux workstation: standalone home-manager — `just switch workstation`
- Secrets injected via 1Password `op inject` during activation

## Other machines

Check out the .ssh/config for other machines we have access to
- `workstation`: personal workstation running a 5090 
- `jetson-nano`: edge device, jetson orin nano
