---
created: 2026-02-01T19:45:00
title: Add fnm (Fast Node Manager) to CLI tools
area: tooling
files:
  - config/Brewfile
---

## Problem

Currently, the dotfiles setup installs Node.js via Homebrew, but there's no version manager for switching between Node versions. Users working on multiple projects often need different Node versions.

nvm is the traditional solution but has performance issues (written in bash, slow startup).

## Solution

Add fnm (Fast Node Manager) to the Brewfile:
- Rust-based, much faster than nvm
- Drop-in replacement with similar commands
- Better shell integration
- Cross-platform support

Install via: `brew "fnm"`

Will need to add shell initialization to .zshrc in dotfiles/shell/.zshrc (fnm env hook).
