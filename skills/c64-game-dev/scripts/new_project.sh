#!/usr/bin/env bash
# Create a new C64 game project from the bundled starter.
#
#   new_project.sh <target-dir> [name]
#
# Copies the starter (64tass source, Makefile, docs, placeholder art) and the
# asset converters into <target-dir>, sets the build name, and runs git init
# if the directory is not already inside a repository.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
starter="$here/../assets/starter"

if [ $# -lt 1 ]; then
    echo "usage: $0 <target-dir> [name]" >&2
    exit 2
fi
target="$1"
name="$(printf '%s' "${2:-$(basename "$target")}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')"

if [ -e "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    echo "error: $target exists and is not empty" >&2
    exit 1
fi

mkdir -p "$target/tools"
cp -R "$starter/." "$target/"
cp "$here/c64img.py" "$here/png2sprites.py" "$here/png2charset.py" "$target/tools/"
sed -i.bak "s/^NAME     ?= game$/NAME     ?= $name/" "$target/Makefile" && rm "$target/Makefile.bak"

if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$target" init -q
fi

echo "created $target (build name: $name)"
missing=""
for tool in 64tass python3 x64sc c1541; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
    echo "missing tools:$missing"
    echo "  macOS:  brew install tass64 vice"
    echo "  Debian: sudo apt install 64tass vice"
fi
echo "next: cd $target && make"
