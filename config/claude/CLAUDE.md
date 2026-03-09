# Global Rules

## Package Managers

- **JS**: use `pnpm`, never `npm`. node is managed by nvm, default version via nix.
- **Python**: use `uv` for everything. `uv run` for scripts, `uv sync` for projects, `uv tool install` for global CLI tools. never `pip install`.
- **Rust**: use `cargo` via `rustup`.

## Commits

- Use conventional commits (feat:, fix:, chore:, docs:)
- Sign commits with 1Password SSH key (commit.gpgsign = true)
- If signing hangs (non-interactive context), use `git -c commit.gpgsign=false commit`

## Environment

- nix-darwin + home-manager manages this machine
- Config lives at `~/all/dots`
- `just switch` to rebuild
- Secrets injected via 1Password `op inject` during activation
- Don't create .env files manually — they come from `secrets/secrets.zsh.tmpl`
