# Stow Symlink Management

This document provides commands to manage symlinks for configuration files using GNU Stow.

## Directory Structure

```text
~/dotfiles/
├── bash/
│   ├── .bash_aliases
│   ├── .fcitx.bash
│   ├── .general.bash
│   ├── .local.bash
│   ├── .oh_my_posh.bash
│   └── oh-my-posh-themes/
├── claude/
│   └── .claude/
│       └── settings.json
├── config/
│   └── .config/
│       ├── fontconfig/
│       ├── nvim/
│       ├── tmux/
│       └── wezterm/
└── fonts/
    └── .fonts/
```

## Stowing Configurations

Navigate to the directory containing your dotfiles:

```bash
cd ~/dotfiles
```

Stow specific configurations:

```bash
stow bash
stow claude
stow config
stow fonts
```

## Unstowing Configurations

To remove symlinks for a specific configuration:

```bash
stow -D bash
# or
stow -D config
# or
stow -D fonts
# or
stow -D claude
```

## Important Note on Existing Files

If the destination file already exists in your home directory (for example, `~/.claude/settings.json`), GNU Stow will throw a **conflict error** and refuse to create the symlink.

To resolve this, you must move or remove the existing file before stowing. For example:

```bash
# 1. Create the missing directory structure in your dotfiles
mkdir -p ~/dotfiles/claude/.claude

# 2. Move the existing file to your dotfiles directory
mv ~/.claude/settings.json ~/dotfiles/claude/.claude/

# 3. Stow the configuration
cd ~/dotfiles
stow claude
```
