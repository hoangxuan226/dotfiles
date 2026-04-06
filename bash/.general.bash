export PATH="$PATH:/opt/nvim/"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# fcitx
if [ -f ~/.fcitx.bash ]; then
  source ~/.fcitx.bash
fi
# Auto-start fcitx5 (WSL-specific) in wezterm only
# wrap the call in a subshell forcing all job control output to be handled by a headless subshell
# hide the job control output of this call
if [[ -n "$WEZTERM_EXECUTABLE" ]]; then
  s() {
    # pkill -f "fcitx5"  # Kill any existing fcitx5 processes
    (fcitx5 --disable=wayland -rd --verbose '*'=0 &)
  }
  s
fi

# oh-my-posh
# use which oh-my-posh to find the installation path
export PATH="$HOME/.local/bin:$PATH"
if [ -f ~/.oh_my_posh.bash ]; then
  source ~/.oh_my_posh.bash
fi
