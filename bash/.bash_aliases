# extract file
extract() {
  if [ -f "$1" ]; then
    case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz) tar xzf "$1" ;;
    *.tar.xz) tar xJf "$1" ;;
    *.tar) tar xf "$1" ;;
    *.tbz2) tar xjf "$1" ;;
    *.tgz) tar xzf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.gz) gunzip "$1" ;;
    *.xz) unxz "$1" ;;
    *.zip) unzip "$1" ;;
    *.rar) unrar x "$1" ;;
    *.7z) 7z x "$1" ;;
    *) echo "❌ Không hỗ trợ loại file này" ;;
    esac
  else
    echo "❌ Không tìm thấy file: $1"
  fi
}

# ======== HSMS
# Alias for opening Neovim with minimal configuration
alias nvimm='nvim -u ~/.config/nvim/minimal.lua'

# Alias for manual click hide decorations
alias hidedecor='xprop -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS "2, 0, 0, 0, 0"'

# Alias for manual click show decorations
alias showdecor='xprop -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS "0, 0, 0, 0, 0"'
