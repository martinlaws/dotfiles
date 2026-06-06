# Initialize completion system
autoload -Uz compinit
compinit

# Aliases
alias mbrew="arch -arm64 brew"
alias lfg="claude --dangerously-skip-permissions"
alias chaos="cd ~/code/chaos && claude"   # one keystroke into the knowledge base

# Add a default scripts folder to $PATH
path+=($HOME/.bin)

[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

# fnm (Fast Node Manager) - Rust-based Node version manager
eval "$(fnm env --use-on-cd)"

eval "$(starship init zsh)"

# Modern CLI tools (guarded so a fresh shell pre-install doesn't error)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"   # z <partial> to jump
command -v atuin  >/dev/null && eval "$(atuin init zsh)"    # ctrl-R history search
if command -v fzf >/dev/null; then
  source <(fzf --zsh) 2>/dev/null                           # ctrl-T / ctrl-R / alt-C
fi

# eza / bat aliases (only if installed)
if command -v eza >/dev/null; then
  alias ls="eza --group-directories-first"
  alias ll="eza -la --group-directories-first --git"
  alias lt="eza --tree --level=2"
fi
command -v bat >/dev/null && alias cat="bat --paging=never"

export PATH="$HOME/.bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/mlaws/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Load local overrides if they exist
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
