# Initialize completion system
autoload -Uz compinit
compinit

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(macos)

# Aliases
alias mbrew="arch -arm64 brew"
alias gsd="claude --dangerously-skip-permissions"

# Add a default scripts folder to $PATH
path+=($HOME/.bin)

[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

# fnm (Fast Node Manager) - Rust-based Node version manager
eval "$(fnm env --use-on-cd)"

eval "$(starship init zsh)"

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
