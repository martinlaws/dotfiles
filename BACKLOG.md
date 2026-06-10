# dotfiles — setup DX backlog

Improvements to the `sh setup` experience. Shipped items are listed for context;
the open ones are **deliberately deferred** (logged 2026-06-07 — not urgent, the
setup works end-to-end; these are polish for the next machine / re-image).

## Shipped (Jun 2026)

- **Per-cask foreground install** (`install-apps.sh`) — installs each cask one at a
  time with `[N/total]` progress, so brew's download bars and any password prompt
  are visible/answerable. (Replaced a single bundled `brew bundle` behind a spinner
  that hung for hours on a hidden sudo prompt.)
- **Stream `install-tools.sh`** the same way — no blind spinner on the CLI/fnm step.
- **Run transcript** — `setup` re-execs through `/usr/bin/script -q` into
  `~/.local/state/dotfiles-setup.log` (preserves the pty so gum still renders).
- **Strict mode + ERR trap** (`✗ failed at <script>:<line>`) on install-homebrew /
  install-tools / install-apps.
- **`scripts/doctor.sh` (#11)** — codified the FIRST-RUN verify checks (brew health
  incl. macOS-ahead/`:dunno` detection, Brewfile tools, fnm node, GitHub SSH,
  symlinks, `~/.claude` repo state + drift, chaos autosave, `/slurp` deps) into one
  read-only health command. Born from the Jun 2026 new-Mac bring-up.
- **macOS-ahead-of-Homebrew fallback** — `maybe_fake_unsupported_macos()` in
  detect.sh auto-sets `HOMEBREW_FAKE_MACOS` during install-tools when the OS major
  is newer than brew's version table (the macOS 27 `:dunno` failure).
- **Brew-managed tool detection** — `is_tool_installed` checks `brew list` instead
  of `command -v <formula>` (formula names ≠ binary names; killed phantom
  "failed to install" reports).
- **`--adopt` on cask installs** — already-hand-installed apps (1Password per
  FIRST-RUN order) get adopted into brew instead of failing.
- **setup-claude SSH check pipefail fix** — capture-then-grep; the old direct pipe
  always failed because `ssh -T git@github.com` exits non-zero even on success.
- **Default to installing ALL casks** (no picker).

## Deferred — high value

### Unattended setup (#6 + #7) — "run it and walk away"
Prompts are scattered today (git name/email in `setup-git`, "restore Claude
config?" in `setup-claude`, cask sudo prompts in phase 3) → two babysitting windows.
- **Front-load inputs (#6):** gather git name/email + the confirms at minute 0, or
  read from a `~/.config/dotfiles.env`; phase scripts consume those instead of
  prompting. Config present → zero prompts.
- **sudo pre-auth + `--unattended` (#7):** `sudo -v` once up front + a background
  keepalive (`sudo -n true` every ~50s, trap-cleaned on exit) so cask installs
  don't block mid-run — the pattern Homebrew's own installer uses. `--unattended`
  implies front-loaded inputs + safe defaults for every "continue anyway?".
- Effort: medium · Risk: low (no state-model changes) · best done as one feature.

### Phase/step resume (#4) — "don't redo phase 1 after a failure"
`state_init` only writes at the very end of `setup`, so any mid-run failure forces
a full re-run. Write a completion marker per step; skip done steps on re-run; add
`--redo [step]` to force.
- **Catch:** `setup` keys first-run-vs-update mode on `state_exists`. Partial state
  written mid-failure would wrongly flip the next run into *update* mode instead of
  *resuming* first-run — needs a separate "first-run complete" sentinel.
- Effort: medium-high (control flow + state). Value declines as the scripts
  stabilize; mainly useful while actively iterating on setup itself.

## Deferred — polish

- **Remaining `ui_spin` footguns (#2):** update-mode scripts (`update-homebrew`,
  `update-apps`, `run-updates`) still wrap long ops in `ui_spin`, which hides output
  + detaches stdin. Stream them too.
- **Preflight checks (#8):** up front — network reachable, free disk, macOS/arch,
  1Password present — warn early instead of failing deep at the SSH/secrets stage.
- **Symlink backup clutter (#9):** `symlink-dotfiles.sh` re-backs-up `~/.zshrc` etc.
  on every run even when it's already the correct symlink — skip if already linked.
- **Overall progress (#10):** "Phase 2/4" + elapsed time.
- **`--dry-run` (#12):** preview installs/symlinks without doing them.
