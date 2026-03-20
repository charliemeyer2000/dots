# Global Rules

## Coding Practice

- Always **ultrathink** about the codebase, structure, patterns, existing files/utilities. Think - what's a high-quality, senior-engineer implementation for this? 
- If you're lost, always read documentation, or consult the user for guidance.
- Read the AGENTS.md (CLAUDE.md symlinks here)

## Documentation

When reading documentation, always:
- Check what version you are using to ensure the documentation you're reading aligns with the version of the package you're using. 
- When fetching, always start by searching for the `llms.txt`. If the documentation supports it, fetch the `.md` version of docs rather than the regular docs. 
- If you can't find docs, we suggest manually inspecting the installed package/tool for its generated code, or ask the user for guidance.


## Package Managers

- JS: use `pnpm`, never `npm`. node is managed by nvm, default version via nix.
- Python: use `uv` for everything. `uv run` for scripts, `uv sync` for projects, `uv tool install` for global CLI tools. never `pip install`.
- Rust: use `cargo` via `rustup`.

## Commits

- Use conventional commits (feat:, fix:, chore:, docs:)
- Sign commits with 1Password SSH key (commit.gpgsign = true)
- If signing hangs (non-interactive context), use `git -c commit.gpgsign=false commit`

## Environment

- Config lives at `~/all/dots`
- macOS: nix-darwin + home-manager — `just switch darwin-personal`
- Linux workstation: standalone home-manager — `just switch workstation`
- Secrets injected via 1Password `op inject` during activation

## Other machines

Check out the .ssh/config for other machines we have access to
- `workstation`: personal workstation running a 5090 
- `jetson-nano`: edge device, jetson orin nano
