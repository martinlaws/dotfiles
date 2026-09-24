# First run — new machine runbook

Step-by-step for bringing up a fresh Mac with this repo. The **order matters**:
1Password unlocks SSH, SSH unlocks the private repos, and so on down the chain.

## 0 · macOS first boot

- Finish Setup Assistant: Apple ID, Wi-Fi, FileVault on.
- Open **Terminal** (Spotlight → "Terminal").

## 1 · 1Password first (the linchpin)

Everything downstream depends on it — your SSH key *and* your secrets live here.

- Install 1Password from 1password.com and **sign in**.
- Turn on the SSH agent: **Settings → Developer → Use the SSH agent**.
- Your single SSH key already lives in 1Password and is already on GitHub, so the
  moment the agent is live you can authenticate with no key generation.

## 2 · Clone + run

```sh
# HTTPS clone — no SSH key on disk needed for a public repo
git clone https://github.com/martinlaws/dotfiles.git ~/dotfiles
cd ~/dotfiles
sh setup
```

`setup` triggers the Xcode Command Line Tools install first (accept the dialog,
wait), then runs its four phases.

## 3 · Answer the prompts — all at minute 0

`setup` asks everything up front, then runs hands-off:

- **Git identity** — name + email for `~/.gitconfig`.
- **Claude config** — restore the private `claude-config` repo into `~/.claude`?
- **SSH** — with the 1Password agent live, it detects the key and **skips the
  question entirely** ("1Password SSH agent holds a key — not minting a local key").
- **System defaults** — one yes/no for the opinionated macOS settings (run
  `scripts/configure-system.sh` on its own for the per-item picker).
- **Your password** — `sudo` is authorized once here and kept warm in the
  background, so cask installs never stall on a hidden prompt mid-run.

Want **zero** prompts? Write the answers to `~/.config/dotfiles.env` first
(every key optional and documented in `scripts/lib/inputs.sh`), and/or run
`sh setup --unattended` — missing answers fall back to safe defaults and every
"continue anyway?" auto-continues:

```sh
mkdir -p ~/.config && cat > ~/.config/dotfiles.env <<'EOF'
DOTFILES_GIT_NAME="Martin Laws"
DOTFILES_GIT_EMAIL="hey@mlaws.ca"
DOTFILES_RESTORE_CLAUDE=yes
DOTFILES_APPLY_SYSTEM_SETTINGS=yes
DOTFILES_CONTINUE_ON_ERROR=yes
EOF
```

> The private `claude-config` clone (phase 4 of setup) needs your SSH public key
> on github.com/settings/keys. It's already there from before — but if that clone
> fails, add the key and re-run `sh setup` (it's idempotent).

## 4 · Restore secrets

Per [`SECRETS.md`](SECRETS.md), two buckets — do it per-project as you start
working in each, not all at once:

- **Vercel-linked** (`.vercel/project.json` present): `vercel link && vercel env pull`.
- **Everything else**: copy keys from 1Password into that project's `.env.local`.

## 5 · Re-auth Claude Code

- `~/.claude` is already restored (setup phase 4 cloned it).
- Launch Claude Code, **sign in** — it regenerates `.credentials.json`.
- Re-add any MCP servers (machine-local, not tracked).

## 6 · The one manual tweak

- **Caps Lock → Esc**: System Settings → Keyboard → Keyboard Shortcuts →
  Modifier Keys.

## 7 · App configs that don't restore from this repo

These live outside the repo (private data or vendor cloud) — restore each by hand:

- **superwhisper** — install the app (`sh setup` installs the cask), launch once,
  then copy your custom modes + vocabulary back from the iCloud backup:
  ```sh
  SRC="$HOME/Library/Mobile Documents/com~apple~CloudDocs/mac-migration/superwhisper"
  cp -R "$SRC/modes/"*    ~/Documents/superwhisper/modes/
  cp -R "$SRC/settings/"* ~/Documents/superwhisper/settings/
  ```
  (Backed up there because `~/Documents` isn't iCloud-synced and the config holds
  personal/client names — see that folder's `RESTORE.md`.)
- **Raycast** — just **sign in**. Cloud Sync restores snippets, hotkeys, and
  presets automatically (nothing to copy). Re-grant Accessibility permission.
- **Comet / Perplexity** — Comet installs from the cask; sign in. Perplexity
  desktop is a manual download (no cask).
- **superwhisper Capture mode** — restores with the other modes; assign it a
  hotkey in superwhisper. Captures are pulled into chaos `_inbox.md` by the
  `/slurp` skill (run anytime) and automatically at the start of `/daily` — both
  live in the chaos repo (`.claude/skills/slurp/`). Needs `jq`.
- **AeroSpace** (window manager) — installs from the cask; config is stowed to
  `~/.config/aerospace/`. First launch: grant **Accessibility** permission, and in
  System Settings → Desktop & Dock turn **off** "automatically rearrange Spaces".
  `alt-1..4` jumps contexts; windows float by default — see the config's bottom
  note to adopt tiling.

## 8 · chaos autosave (auto-installed by setup)

`setup` loads a background agent (`ca.mlaws.chaos-autosave`) that snapshots the
whole chaos working tree — *including untracked notes* — ~90s after you stop
editing, and pushes it only when something changed. Never touches your working
tree or `main`. A sibling agent (`ca.mlaws.claude-autosave`) does the same for
`~/.claude`'s tracked brain.

Each Mac pushes its own branch so neither overwrites the other: the Studio pushes
`autosave`, any other Mac pushes `autosave-<LocalHostName>` (read with
`/usr/sbin/scutil --get LocalHostName`, never the network hostname;
`scripts/setup-autosave.sh` prints it). Every Mac also keeps its latest snapshot
locally at `refs/autosave/latest`, even when a push fails, and retries a failed
push after 15 quiet minutes.

Recover a lost note (`git restore` puts the file back in your working tree only;
nothing is staged):
```sh
# same Mac — local, freshest, no network
cd ~/code/chaos && git restore --source=refs/autosave/latest -- path/to/note.md

# from GitHub — the Studio's snapshot
cd ~/code/chaos && git fetch origin && git restore --source=origin/autosave -- path/to/note.md
# …or another Mac's:  git restore --source=origin/autosave-<host> -- path/to/note.md
```
⚠ `git checkout autosave -- <file>` does NOT work: there is no local `autosave`
branch, and with `-- <path>` git won't guess the remote one (`fatal: invalid
reference`). Same commands in `~/.claude` for claude-config. Or browse the branch on
GitHub. Logs: `~/.local/state/chaos-autosave.log` (rolls to `.log.1` past 2 MB).
Re-arm manually any time: `scripts/setup-autosave.sh`.

## Verify it worked

```sh
exec zsh                 # fresh shell
node --version           # fnm serves LTS
which node               # → ...fnm_multishells/...  (not .nvm)
z ~                      # zoxide works
ssh -T git@github.com    # authenticates via the 1Password agent
```

Then open Claude Code in a project and confirm the statusline renders and skills
load — that proves the `~/.claude` brain + hooks survived the move.

---

**Critical-path chain:** 1Password sign-in → SSH agent live → private repos
clone → secrets restore. Get 1Password right first and the rest follows.

**Before wiping the old machine:** confirm every working repo under `~/code` is
pushed — uncommitted work doesn't survive. The config repos are already safe.
Also confirm: (1) superwhisper modes are in the iCloud `mac-migration/` backup,
(2) Raycast shows a recent Cloud Sync date, (3) you're signed into 1Password and
the SSH agent is on. Those three cover the configs the repo can't carry.
