#!/usr/bin/env bash

DOTFILES="$HOME/dotfiles"
OS=$(uname)

# helper
link() {
  local src="$DOTFILES/$1"
  local dest="$HOME/$2"
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  echo "✓ Linked $1 → $dest"
}

# ── Shared ─────────────────────────────────────────────
# tmux
link config/tmux/tmux.conf .config/tmux/tmux.conf

# nvim
link config/nvim .config/nvim

echo "-> General done!"

# ── macOS ──────────────────────────────────────────────
if [[ "$OS" == "Darwin" ]]; then
  echo "-> For zsh:"
  # zsh
  link zsh/.zshrc .zshrc
  link zsh/.zsh_aliases .zsh_aliases

  # kitty
  link config/kitty .config/kitty

  # hammerspoon
  link hammerspoon/init.lua .hammerspoon/init.lua
  link hammerspoon/vim-in-place.lua .hammerspoon/vim-in-place.lua
  link hammerspoon/vim-overlay.lua .hammerspoon/vim-overlay.lua

# ── Linux ──────────────────────────────────────────────
elif [[ "$OS" == "Linux" ]]; then
  echo "-> For linux:"
  # bash
  link bash/.bashenv .bashenv
  link bash/.bash_aliases .bash_aliases

  # claude
  link claude/settings.json .claude/settings.json
  link claude/statusline.sh .claude/statusline.sh

  # fonts
  link config/fontconfig/fonts.conf .config/fontconfig/fonts.conf
  link config/fontconfig/tff .fonts

  # wezterm
  link config/wezterm .config/wezterm
fi

echo "-> Done!"
