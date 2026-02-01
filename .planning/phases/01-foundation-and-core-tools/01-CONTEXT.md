# Phase 1: Foundation & Core Tools - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the foundation for Mac setup automation by installing Homebrew with correct Apple Silicon paths, installing essential CLI tools (git, nodejs, pnpm, gh, tree, gum, stow), creating the project directory structure (dotfiles/, config/, scripts/, setup entry point), and establishing the beautiful CLI interface pattern that all subsequent phases will use.

</domain>

<decisions>
## Implementation Decisions

### Setup Entry Point & Flow
- Run via `sh setup` (not executable ./setup - no chmod needed)
- Script structure: Claude's discretion (single file vs modular)
- Directory structure: Claude's discretion (all at once vs as-needed)
- Brewfile location: Claude's discretion (config/Brewfile vs root)

### CLI Interface Style
- **Balanced emoji and color** - some emojis for key moments, colors for clarity, not overwhelming
- **Mixed progress indicators** - spinners for unknown duration, progress bars when trackable, step counters for overall progress
- Section separation style: Claude's discretion (Claude picks what looks best with Gum)
- **Verbose flag** - default to showing results only, `--verbose` flag shows commands being run

### Error Handling & Recovery
- Homebrew installation failure: Claude's discretion (fail vs retry strategy)
- **CLI tools partial failure: Prompt per failure** - ask "Tool X failed. Continue anyway?" for each tool that fails
- Dry-run mode: Claude's discretion (decide if valuable for Phase 1)
- Network issues: Claude's discretion (retry strategy, error messaging)

### First-Run Experience
- Greeting/intro: Claude's discretion (friendly vs minimal vs jump right in)
- Preview before install: Claude's discretion (full preview vs summary vs none)
- **Sudo password: Prompt when needed** - don't ask upfront, only when a step requires it
- **End of Phase 1: Detailed report** - show what was installed, paths, versions, next steps

### Claude's Discretion
- Script structure (monolithic vs modular)
- Directory creation strategy (all upfront vs progressive)
- Brewfile location (config/ vs root)
- Section visual separation (Gum styling)
- Homebrew failure handling
- Dry-run mode inclusion
- Network retry strategy
- Greeting/intro style
- Install preview approach

</decisions>

<specifics>
## Specific Ideas

- "I want this to be delightful" - setup should feel fun and engaging, not intimidating
- Beautiful CLI is a core differentiator from typical dotfiles repos
- This is running on a brand new Mac Studio (Apple Silicon) - correct Homebrew paths critical
- User wants to feel in control, not have things happen magically

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-and-core-tools*
*Context gathered: 2026-02-01*
