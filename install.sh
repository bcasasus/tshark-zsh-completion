#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file="$repo_dir/_tshark"
completion_dir="${ZDOTDIR:-$HOME}/.zsh/completions"
target="$completion_dir/_tshark"
zshrc="${ZDOTDIR:-$HOME}/.zshrc"
start_marker='# >>> tshark-zsh-completion >>>'
end_marker='# <<< tshark-zsh-completion <<<' 

if ! command -v zsh >/dev/null 2>&1; then
    printf '%s\n' 'Error: Zsh is required.' >&2
    exit 1
fi
if ! command -v tshark >/dev/null 2>&1; then
    printf '%s\n' 'Error: TShark is required and must be on PATH.' >&2
    exit 1
fi
if [ ! -f "$source_file" ]; then
    printf '%s\n' 'Error: _tshark is missing from this directory.' >&2
    exit 1
fi

mkdir -p "$completion_dir"
if [ -e "$target" ] && ! cmp -s "$source_file" "$target"; then
    backup="$target.backup.$(date +%Y%m%d%H%M%S)"
    while [ -e "$backup" ]; do backup="$backup.1"; done
    cp -p "$target" "$backup"
    printf 'Backed up existing completion to %s\n' "$backup"
fi
cp "$source_file" "$target"
chmod 644 "$target"

if [ ! -e "$zshrc" ]; then : > "$zshrc"; fi
if ! grep -Fqx "$start_marker" "$zshrc"; then
    tmp=$(mktemp "${zshrc}.tmp.XXXXXX")
    {
        printf '%s\n' "$start_marker"
        printf '%s\n' 'fpath=("${ZDOTDIR:-$HOME}/.zsh/completions" $fpath)'
        printf '%s\n' "$end_marker"
        cat "$zshrc"
    } > "$tmp"
    cat "$tmp" > "$zshrc"
    rm -f "$tmp"
fi

# Run compinit if the user's configuration has not initialized completion yet.
if ! grep -Eq '(^|[[:space:]])compinit([[:space:]]|$|;)' "$zshrc"; then
    {
        printf '\n%s\n' 'autoload -Uz compinit'
        printf '%s\n' 'compinit'
    } >> "$zshrc"
fi

printf 'Installed %s\nRestart Zsh with: exec zsh\n' "$target"
