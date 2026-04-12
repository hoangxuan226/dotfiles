# custom bash
if [ -f ~/.bash.d/general ]; then
  source ~/.bash.d/general
fi
if [ -f ~/.bash.d/local ]; then
  source ~/.bash.d/local
fi

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

# Alias for opening Neovim with minimal configuration
alias nvimm='nvim -u ~/.config/nvim/minimal.lua'

# Alias for manual click hide decorations
alias hidedecor='xprop -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS "2, 0, 0, 0, 0"'

# ======== CLAUDE
# Claude Code session removal: claude-rm help
claude-rm() {
  local PROJECTS_DIR="$HOME/.claude/projects"

  if [ -z "${1:-}" ] || [[ "$1" =~ ^(help|-h|--help)$ ]]; then
    echo "Usage:"
    echo "  claude-rm ls         : List all current sessions"
    echo "  claude-rm <id>       : Delete a session by its ID"
    echo "  claude-rm all        : Delete ALL sessions across all projects"
    return 0
  fi

  case "$1" in
  ls)
    echo "--- All Claude Code Sessions ---"
    if [ -d "$PROJECTS_DIR" ]; then
      find "$PROJECTS_DIR" -type f -name "*.jsonl" | while read -r file; do
        local project_dir session_id real_path parsed ts preview
        project_dir=$(basename "$(dirname "$file")")
        session_id=$(basename "$file" .jsonl)
        # Convert format (-home-user-project -> /home/user/project)
        real_path=$(echo "$project_dir" | sed 's|^-|/|; s|-|/|g')

        parsed=$(python3 -c '
          import sys, json, datetime, re
          ts="Unknown"; prompts=[]
          try:
              with open(sys.argv[1], "r", encoding="utf-8") as f:
                  lines = [l.strip() for l in f if l.strip()]
                  for line in reversed(lines):
                      try:
                          r = json.loads(line)
                          if r.get("type") == "user":
                              t_raw = r.get("timestamp", "")
                              c = r.get("message", {}).get("content", "")
                              p = ""
                              if isinstance(c, str):
                                  p = c.replace("\n", " ")
                              elif isinstance(c, list):
                                  p = " ".join(i.get("text", "") for i in c if isinstance(i, dict) and i.get("type") == "text").replace("\n", " ")
                              
                              # Skip tool outputs entirely
                              if not p or "<local-command" in p or "<file" in p or "<grep" in p or "<ls" in p or "<read" in p:
                                  continue
                                  
                              # Clean XML tags (like <command-name>)
                              clean_p = re.sub(r"<[^>]+>", "", p).strip()
                              
                              # Skip trivial commands (check starts_with since tags removal might leave duplicate words like "/exit exit")
                              cp_lower = clean_p.lower()
                              if cp_lower.startswith(("exit", "/exit", "quit", "/quit", "/compact", "/clear", "/cost")):
                                  continue
                                  
                              if clean_p:
                                  prompts.append(clean_p)
                                  # Save timestamp of the newest meaningful prompt
                                  if len(prompts) == 1:
                                      if isinstance(t_raw, (int, float)):
                                          ts = datetime.datetime.fromtimestamp(t_raw/1000).strftime("%Y-%m-%d %H:%M")
                                      elif t_raw:
                                          ts = str(t_raw).replace("T", " ")[:16]
                                  
                                  # Stop after collecting 2 meaningful prompts
                                  if len(prompts) >= 2: break
                      except: pass
                      
              if not prompts: preview = "(no message)"
              else: preview = " ➜ ".join(reversed(prompts))
              
              # Truncate if too long (e.g. 95 chars) to fit terminal
              if len(preview) > 95: preview = preview[:92] + "..."
              print(f"{ts}\n{preview}")
          except:
              print("Unknown\n(no message)")
          ' "$file" 2>/dev/null)

        ts=$(echo "$parsed" | head -n 1)
        preview=$(echo "$parsed" | tail -n +2)
        [ -z "$ts" ] && ts="Unknown"
        [ -z "$preview" ] && preview="(no message)"

        echo -e "Project: \033[33m$real_path\033[0m"
        echo -e "ID:      \033[36m$session_id\033[0m"
        echo -e "Time:    \033[32m$ts\033[0m"
        echo -e "Prompt:  \033[2m$preview...\033[0m"
        echo "--------------------------------"
      done
    else
      echo "No sessions found."
    fi
    ;;
  all)
    echo -n "Are you sure you want to delete ALL sessions? [y/N] "
    read -r -n 1 confirm
    echo
    if [[ "$confirm" =~ ^[yY]$ ]]; then
      rm -rf "${PROJECTS_DIR:?}"/* 2>/dev/null
      echo "All sessions cleared."
    else
      echo "Cancelled."
    fi
    ;;
  *)
    local TARGET_ID="$1"
    if [ ! -d "$PROJECTS_DIR" ]; then
      echo "No sessions found."
      return 1
    fi

    local FOUND
    FOUND=$(find "$PROJECTS_DIR" -name "$TARGET_ID.jsonl" 2>/dev/null)

    if [ -n "$FOUND" ]; then
      find "$PROJECTS_DIR" -name "$TARGET_ID.jsonl" -delete
      find "$PROJECTS_DIR" -type d -name "$TARGET_ID" -exec rm -rf {} + 2>/dev/null
      echo -e "Deleted session: \033[32m$TARGET_ID\033[0m"
    else
      echo -e "\033[31mError:\033[0m Session ID '$TARGET_ID' not found."
      return 1
    fi
    ;;
  esac
}
