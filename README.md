# Dotfiles

A collection of configuration files for my development environment on macOS and WSL.

## Installation

Run the installation script to automatically create the necessary symlinks:

```bash
./install.sh
```

## What's Included

### Shared

- **Neovim** (`config/nvim`)
- **Tmux** (`config/tmux`)

### macOS

- **Zsh** environment and aliases
- **Kitty** terminal emulator
- **Hammerspoon** system management (including Vim-keybindings overlays)

### Linux

- **Bash** environment and aliases
- **WezTerm** terminal emulator
- **Fontconfig**

---

## Manual Notes

### macOS Kitty Configuration

To use `kitty` and `kitten` from the command line, create symlinks in a folder that is within your system-wide PATH (e.g., `/usr/local/bin`):

```zsh
sudo ln -sf /Applications/kitty.app/Contents/MacOS/kitty /usr/local/bin/kitty
sudo ln -sf /Applications/kitty.app/Contents/MacOS/kitten /usr/local/bin/kitten
```

_Tip:_ You can check which primary folders are mapped to your base system paths by inspecting `/etc/paths`:

```zsh
cat /etc/paths
```
