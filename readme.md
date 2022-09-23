# dotfiles

The vast majority of these dotfiles are lovingly ripped off from @graygilmore - many thanks, friend!

Installation made super easy with `stow`.

```bash
stow git tmux vim vscode bash -t ~
```

## Initial Machine Setup

1. [homebrew](https://brew.sh/)
2. [stow](https://www.gnu.org/software/stow/manual/stow.html#Introduction)
3. [Plug.vim](https://github.com/junegunn/vim-plug)

## Dependencies

N.B. since I'm a [fancypants](https://media.giphy.com/media/3orieXKH4P732pAeCA/giphy.gif), my work and personal machines are M1 macs (everyone @Shopify gets an M1 Pro MBP, and my personal machine is a baby blue [M1 iMac](https://www.apple.com/ca/imac/))

### [fzy](https://github.com/jhawthorn/fzy)

```bash
brew update
brew install fzy
```

### [diff-so-fancy](https://github.com/so-fancy/diff-so-fancy)

```bash
brew update
brew install diff-so-fancy
```

### [ripgrep](https://github.com/BurntSushi/ripgrep)

```bash
brew update
brew install ripgrep
```

## Optional

### [n](https://github.com/tj/n)

Let's make use of [n-install](https://github.com/mklement0/n-install) to set up
some defaults for us.

```bash
curl -L https://git.io/n-install | bash
```

### [tmux](https://github.com/tmux/tmux)

```bash
brew update
brew install tmux
```
