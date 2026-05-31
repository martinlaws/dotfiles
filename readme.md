# dotfiles

> macOS setup as code. Clone, run one command, and a bare Mac comes up as my
> machine — shell, git, editor, terminal, apps, and system preferences, all
> configured the way I like them.

Built to be **idempotent** (safe to re-run), **interactive where it matters**
(you pick which apps), and **honest about secrets** (none live here — see
[`SECRETS.md`](SECRETS.md)).

---

## Quick start

```sh
# 1. Sign into 1Password first — secret + SSH restore depend on it.
# 2. Clone over HTTPS (a fresh Mac has no SSH key yet):
git clone https://github.com/martinlaws/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 3. Run the one entrypoint:
sh setup
```

That's it. `setup` detects your architecture, installs Xcode Command Line Tools
and Homebrew, then walks through each phase below. Run it again any time — it
flips into **update mode** and refreshes rather than redoing first-time setup.

---

## What it sets up

| Phase | What happens |
|---|---|
| **1 · Foundation** | Xcode CLT, Homebrew, CLI tools from [`config/Brewfile`](config/Brewfile), Node LTS pinned via fnm |
| **2 · Dev config** | Symlinks shell / terminal / editor / ssh configs (via GNU Stow), generates `~/.gitconfig` from a template, sets up SSH |
| **3 · Apps & system** | Installs GUI apps from [`config/Brewfile.apps`](config/Brewfile.apps) (all / by category / pick-and-choose), applies opinionated macOS defaults |
| **4 · Claude** | Restores my private Claude Code config into `~/.claude` |

A couple of steps stay manual by design — `setup` will prompt you:

- **Git identity** — it asks for the name/email to stamp into `~/.gitconfig`.
- **SSH key on GitHub** — see the SSH note below; you'll paste a public key into
  [github.com/settings/keys](https://github.com/settings/keys).

And after it finishes:

- **Restore secrets** — follow [`SECRETS.md`](SECRETS.md) (1Password + `vercel env pull`).
- **Re-auth Claude Code** — sign in once; it regenerates its own credentials.
- **Caps Lock → Esc** — System Settings → Keyboard → Modifier Keys. (The one
  thing macOS won't let me script cleanly.)

---

## The stack

**Shell** — `zsh` + [Starship](https://starship.rs) prompt. History, navigation,
and listing are upgraded with a modern CLI kit, each wired into `.zshrc` behind a
`command -v` guard so the shell never errors if a tool isn't installed yet:

| Tool | What it does |
|---|---|
| [`atuin`](https://atuin.sh) | Shell history → searchable, synced SQLite (Ctrl-R) |
| [`zoxide`](https://github.com/ajeetdsouza/zoxide) | `cd` that learns — `z <partial>` from anywhere |
| [`eza`](https://eza.rocks) | `ls` with icons, git status, tree view |
| [`bat`](https://github.com/sharkdp/bat) | `cat` with syntax highlighting |
| [`fzf`](https://github.com/junegunn/fzf) | Fuzzy finder (Ctrl-T / Ctrl-R / Alt-C) |
| [`ripgrep`](https://github.com/BurntSushi/ripgrep) | Fast recursive search (`rg`) |
| [`git-delta`](https://github.com/dandavison/delta) | Git's pager + diff filter, made readable |

**Node** — managed by [`fnm`](https://github.com/Schniz/fnm) only. `.zshrc` runs
`fnm env --use-on-cd` (auto-switch per directory), and setup pins `lts-latest` as
the default so a fresh machine has a working `node`/`npm` immediately.

**Git** — sensible aliases, `delta` for diffs, `zdiff3` conflict style, and a
`~/.git-template` that seeds every `git init`.

---

## SSH: one key, in 1Password

There's no per-machine SSH key to manage. The committed `~/.ssh/config` points
SSH at the **1Password SSH agent** (`IdentityAgent`), so a single key lives in
1Password and follows me to any machine — nothing private ever touches disk.

`scripts/setup-ssh.sh` checks the agent: if it already holds a key, setup skips
key generation entirely. If 1Password isn't present (or the key hasn't been added
yet), it falls back to minting a local `~/.ssh/id_ed25519` and prints the public
half to add to GitHub. Either way you end up connected.

---

## Layout

```
setup                  ← the only entrypoint:  sh setup
config/
  Brewfile             ← CLI formulae
  Brewfile.apps        ← GUI casks, grouped by category
dotfiles/              ← Stow packages, symlinked into ~
  shell/     .zshrc · .vimrc · .config/starship.toml
  git/       .gitconfig.template · .gitignore_global · .git-template/
  terminal/  .hyper.js
  editors/   VS Code settings
  ssh/       .ssh/config
scripts/               ← one file per concern (+ lib/ helpers)
SECRETS.md             ← how to restore secrets (no secrets in here)
```

---

## On secrets

Nothing sensitive lives in this repo — that's the whole point, and it's why I'm
comfortable making it public. **1Password is the source of truth**; runtime
secrets land in per-project `.env.local` files (gitignored), and Vercel-managed
projects pull their own. The full restore playbook is in [`SECRETS.md`](SECRETS.md).

`.gitignore` blocks `*.local` and `.claude/` as a backstop. Anything
machine-specific goes in a `.local` file; anything private goes in a private
repo. The public repo stays clean by construction.

---

## Related

- **[`martinlaws/claude-config`](https://github.com/martinlaws/claude-config)**
  *(private)* — my Claude Code skills, agents, hooks, and memory; restored into
  `~/.claude` by `scripts/setup-claude.sh`.
