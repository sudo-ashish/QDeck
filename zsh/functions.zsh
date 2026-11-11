mkcd() {
  mkdir -p "$1" && cd "$1"
}

gitcd() {
  git clone "$@" || return
  local dir="${2:-$(basename "$1" .git)}"
  cd "$dir" || return
}

gctmp() {
  cd /tmp || return
  git clone "$@" || return
  local dir="${2:-$(basename "$1" .git)}"
  cd "$dir" || return
}

gitpt() {
  [[ $# -eq 2 ]] || {
    echo "Usage: gitpt <repo-url> <folder-path>"
    return 1
  }

  local repo="$1"
  local folder="$2"
  local dir
  dir="$(basename "$repo" .git)"

  cd /tmp || return
  git clone --filter=blob:none --sparse "$repo" || return
  cd "$dir" || return
  git sparse-checkout set "$folder" || return
}