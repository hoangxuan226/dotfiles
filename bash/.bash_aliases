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
# Alias for building and pushing backend-dev Docker image
alias hsms-dbe='docker build -f Dockerfile -t hsms68/backend-dev:latest . && docker push hsms68/backend-dev:latest'

# Alias for building and pushing frontend-staging Docker image
alias hsms-dfe='docker compose build frontend-staging && docker push hsms68/frontend-staging:latest'

# Alias for local revalidate API
alias hsms-rvld-l='curl -X POST "http://localhost:3000/api/revalidate?path=/,layout"'

# Alias for staging revalidate API
alias hsms-rvld-s='curl -X POST "https://staging.hsms.io.vn/api/revalidate?path=/,layout"'
