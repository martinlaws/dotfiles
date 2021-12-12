# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(macos)

# Aliases
alias mbrew="arch -arm64 brew"

# Add a default scripts folder to $PATH
path+=($HOME/.bin)

# Use fzy for finding paths
# By default, ^S freezes terminal output and ^Q resumes it. Disable that so
# that those keys can be used for other things.
unsetopt flowcontrol
# Run Selecta in the current working directory, appending the selected path, if
# any, to the current command, followed by a space.
function insert-fzy-path-in-command-line() {
    local selected_path
    # Print a newline or we'll clobber the old prompt.
    echo
    # Find the path; abort if the user doesn't select anything.
    selected_path=$(rg . -l -g '' | fzy) || return
    # Append the selection to the current command buffer.
    eval 'LBUFFER="$LBUFFER$selected_path "'
    # Redraw the prompt since Selecta has drawn several new lines of text.
    zle reset-prompt
}
# Create the zle widget
zle -N insert-fzy-path-in-command-line
# Bind the key to the newly created widget
bindkey "^S" "insert-fzy-path-in-command-line"

# Ruby // Shopify dev stuff
if ! [ "$SPIN" ] && ! [[ -f /opt/dev/sh/chruby/chruby.sh ]]; then
    source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
    source /opt/homebrew/opt/chruby/share/chruby/auto.sh
fi

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; }
[ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

eval "$(starship init zsh)"