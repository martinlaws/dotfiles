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

## 3 · Answer the prompts

- **Git identity** — name + email for `~/.gitconfig`.
- **SSH** — with the 1Password agent live, it detects the key and **skips
  keygen** ("1Password SSH agent holds a key — not minting a local key").
- **Apps** — "Install all", or pick by category for a leaner machine.
- **System defaults** — accept the opinionated macOS settings.

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
