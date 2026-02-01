# Phase 2: Dotfiles & Developer Config - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Automate dotfiles symlinking and developer environment configuration with SSH/Git setup. User's shell configs, editor settings, Git configuration, and SSH setup are in place and working on a fresh Mac. This phase makes personal development environment portable and reproducible.

</domain>

<decisions>
## Implementation Decisions

### Dotfile organization & symlinking
- Use GNU Stow for symlinking (industry standard, reliable, handles nested structures)
- Organization structure is at Claude's discretion (flat vs nested vs mirrored home structure)
- Backup existing files before symlinking: Move to `~/.filename.backup.TIMESTAMP` format
- Same approach for both root dotfiles (.zshrc) and .config/ directory configs (starship.toml)

### SSH & Git configuration
- **Git config:** Use `.gitconfig.template` in repo, prompt for user.name and user.email during setup to generate personalized `~/.gitconfig` (not symlinked, for shareability)
- **SSH keys:** Check for existing keys (~/.ssh/id_ed25519 or similar), prompt to generate if missing with interactive prompts for email and passphrase
- **SSH config:** Claude decides whether to template or symlink based on config content (inspect for user-specific values)
- **Connectivity verification:** Test SSH connection to github.com after setup (`ssh -T git@github.com`) and show success/failure with instructions

### Local overrides & machine-specific settings
- Support .local override files for: shell (.zshrc.local), git (.gitconfig.local), SSH (.ssh/config.local), and all configs by convention
- Don't create stub .local files — only mention pattern in documentation, user creates when needed
- Add `*.local` to .gitignore to prevent accidental commits of machine-specific settings
- Documentation approach for .local pattern is at Claude's discretion

### Config validation & user guidance
- Validate config files before symlinking (check syntax and required fields like git user.name)
- When validation finds issues: Stop setup with clear error message BUT prompt user "Continue anyway?" for control
- Provide concise actionable messages for missing/incomplete configs (e.g., "Missing user.name in .gitconfig. Run: git config --global user.name \"Your Name\"")
- Detailed summary at end with verification: Show checklist of what was configured (✓ Shell configs symlinked, ✓ Git configured, ✓/✗ SSH test status)

### Claude's Discretion
- Exact dotfiles directory organization structure (flat/nested/mirrored)
- Whether SSH config needs templating or can be symlinked as-is
- Documentation approach for .local override pattern (README, inline comments, or both)
- Validation level balance (thoroughness vs complexity)
- Summary report styling details

</decisions>

<specifics>
## Specific Ideas

- "Other people might use my dotfiles in the future" — Shareability is important, hence template-based .gitconfig rather than symlinked
- Git config should prompt during setup so different users can use the same dotfiles repo
- Backup existing configs rather than overwriting — safety first approach
- Test GitHub connectivity as part of verification — want to know immediately if SSH setup works

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-dotfiles-developer-config*
*Context gathered: 2026-02-01*
