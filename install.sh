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
  echo "-> zsh"
  # zsh
  link zsh/.zshrc .zshrc
  link zsh/.zsh_aliases .zsh_aliases

  # kitty
  link config/kitty .config/kitty

# ── Linux ──────────────────────────────────────────────
elif [[ "$OS" == "Linux" ]]; then
  echo "-> bash"
  # bash
  link bash/bash.d .bash.d
  link bash/.bash_aliases .bash_aliases

  # oh-my-posh
  link themes/oh_my_posh oh-my-posh-themes

  # claude
  link claude .claude

  # fonts
  link config/fontconfig/fonts.conf .config/fontconfig/fonts.conf
  link config/fontconfig/tff .fonts

  # wezterm
  link config/wezterm .config/wezterm
fi

echo "-> Done!"
