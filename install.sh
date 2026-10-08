#!/usr/bin/env bash
# Install the c64-game-dev skill for Claude Code and/or Codex.
#
#   ./install.sh [--claude] [--codex] [--copy]
#
# Without --claude/--codex both are installed. Default is a symlink, so a
# `git pull` in this repository updates the installed skill.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill="$repo/skills/c64-game-dev"
targets=()
mode=link

for arg in "$@"; do
    case "$arg" in
        --claude) targets+=("${CLAUDE_HOME:-$HOME/.claude}/skills") ;;
        --codex)  targets+=("${CODEX_HOME:-$HOME/.codex}/skills") ;;
        --copy)   mode=copy ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done
if [ ${#targets[@]} -eq 0 ]; then
    targets=("${CLAUDE_HOME:-$HOME/.claude}/skills" "${CODEX_HOME:-$HOME/.codex}/skills")
fi

for dir in "${targets[@]}"; do
    mkdir -p "$dir"
    dest="$dir/c64-game-dev"
    if [ -L "$dest" ]; then
        rm "$dest"
    elif [ -e "$dest" ]; then
        echo "skip: $dest exists and is not a symlink (remove it to reinstall)" >&2
        continue
    fi
    if [ "$mode" = copy ]; then
        cp -R "$skill" "$dest"
    else
        ln -s "$skill" "$dest"
    fi
    echo "installed: $dest"
done
