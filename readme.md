# dotfiles

Martin's macOS machine setup — shell, git, editor, terminal configs plus a
scripted, idempotent installer. Clone, run `sh setup`, and a fresh Mac comes up
configured.

## New machine, from zero

```sh
# 1. Sign into 1Password first — secrets restore depends on it (see SECRETS.md).
# 2. Clone. First time, use HTTPS — SSH keys don't exist yet (chicken-and-egg):
git clone https://github.com/martinlaws/dotfiles.git ~/dotfiles
cd ~/dotfiles
# 3. Run the installer:
sh setup
```

`setup` is the **only** entrypoint. It detects architecture, installs Xcode CLT
+ Homebrew, then runs each phase. Re-running it enters **update mode** (a state
file at first run flips it) rather than redoing first-time setup.

During the run it will:
- **set up SSH** — if the 1Password SSH agent is present, it wires it via
  `~/.ssh/config.local` and skips minting a key (your key lives in 1Password); add
  its public key to **github.com/settings/keys** so the private claude-config clone
  can succeed. Without 1Password it falls back to generating `~/.ssh/id_ed25519`
  and printing the public key to add.
- prompt for git name/email to generate `~/.gitconfig` from the template

After it finishes:
- **Restore secrets** per `SECRETS.md` — 1Password → `.env.local` for non-Vercel
  projects; `vercel link && vercel env pull` for Vercel-linked ones
- **Re-auth Claude Code** (regenerates `~/.claude/.credentials.json`)
- **Remap Caps Lock → Esc**: System Settings → Keyboard → Keyboard Shortcuts →
  Modifier Keys (still manual)

## What `setup` does (phases)

1. **Foundation** — Xcode CLT, Homebrew, CLI tools from `config/Brewfile`,
   pins Node LTS via fnm
2. **Dotfiles & dev config** — stow-symlinks shell/terminal/editor/ssh configs,
   generates `~/.gitconfig` from template, symlinks `~/.git-template`, sets up
   SSH key + GitHub verification
3. **Applications & system** — `config/Brewfile.apps` (interactive: all /
   categories / individual), opinionated macOS `defaults`
4. **Claude config** — clones the private `claude-config` repo into `~/.claude`

## Layout

```
setup                     # entrypoint — `sh setup`
config/
  Brewfile                # CLI formulae (+ Node LTS pinned by install-tools.sh)
  Brewfile.apps           # GUI casks, categorized
dotfiles/                 # stow packages (symlinked into ~)
  shell/   .zshrc, .vimrc, .config/starship.toml
  git/     .gitconfig.template, .gitignore_global, .git-template/
  terminal/.hyper.js
  editors/ VS Code settings
  ssh/     .ssh/config
scripts/                  # one file per concern, + lib/ helpers
SECRETS.md                # secrets restore checklist (no secrets in repo)
```

## Toolchain notes

- **Node**: managed by **fnm only** (nvm + mise were removed). `.zshrc` runs
  `fnm env --use-on-cd`; `install-tools.sh` pins `lts-latest` as default so a
  fresh machine has working node immediately.
- **Modern CLI**: `atuin` (synced history), `zoxide` (`z` jump), `eza`, `bat`,
  `fzf`, `ripgrep`, `git-delta`. `.zshrc` inits each behind a `command -v`
  guard, so a shell opened before install still works.
- **git**: uses `delta` as pager + diff filter; `~/.git-template` seeds every
  `git init`.

## Related repos

- **`martinlaws/claude-config`** (private) — Claude Code skills/agents/hooks/
  memory; restored into `~/.claude` by `scripts/setup-claude.sh`.

## Conventions

- Secrets never live here — 1Password + per-project `.env.local` (see
  `SECRETS.md`). `.gitignore` blocks `*.local` and `.claude/`.
- One concern per script in `scripts/`; shared helpers in `scripts/lib/`.
- `setup.sh` (the old entrypoint) was removed — use `sh setup`.
