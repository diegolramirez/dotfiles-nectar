# dotfiles-nectar

ThinkNectar profile overlay repository, cloned automatically to `~/Developer/dotfiles/dotfiles-nectar` (symlinked at `~/.config/dotfiles-overlay`) by `chezmoi`.

## Contents
- `Brewfile` — ThinkNectar CLI tools & casks (`uv`, `teleport`, `1password-cli`, `claude-code`).
- `zsh/` — `uv` OMZ plugin plus `aws_profile`, `aws-export`, `nocorrect tsh`, and Teleport `tsh-*` aliases.
- `git/` — ThinkNectar Git author identity (`diegoramirez@thinknectar.com`).
- `ssh/` — ThinkNectar SSH hosts (`github.com`, `pipes-dev`, `pipes-prod`, `pipes-demo`).
- `vscode/` — Clean ThinkNectar VS Code overlay (`claudeCode.*`, Airflow `cSpell.userWords`, `anthropic.claude-code`).
- `claude/` — ThinkNectar `CLAUDE.md` (`nectar_db` rule), `settings.json` (`PreToolUse` Co-Authored-By hook, subagent env vars, plugins, effort levels).
- `t3/` — ThinkNectar T3 Code `claudeAgent` provider configuration.
- `skills/` — Migrated ThinkNectar skills (`my-tickets`, `my-tickets-priority`, `pipes-standup-report`, `review-teammate-pr`).
