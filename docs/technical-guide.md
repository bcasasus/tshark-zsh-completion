# TShark Zsh Completion — Technical Guide

## 1. What Language Is This?

The completion is primarily written in **Zsh scripting**.

It also invokes standard Unix utilities such as:

```text
awk
sed
sort
head
mv
mkdir
rm
```

and commands exposed by TShark itself.

The script additionally uses Zsh's completion framework:

```text
_arguments
_describe
fpath
compinit
```

So there are three layers of syntax to understand:

```text
Zsh language
+
Zsh completion framework
+
Unix/TShark commands
```

## 2. Native Zsh Completion Model

The file is named:

```text
_tshark
```

and starts with:

```zsh
#compdef tshark
```

This tells Zsh that the completion belongs to the `tshark` command.

The file lives in a directory included in `fpath`, for example:

```text
~/.zsh/completions/_tshark
```

with:

```zsh
fpath=(~/.zsh/completions $fpath)

autoload -Uz compinit
compinit
```

in `~/.zshrc`.

Unlike a normal script loaded with `source`, a native completion is discovered and loaded through Zsh's completion system.

## 3. Global Variables

The script uses `typeset` to declare global variables.

```zsh
typeset -g _TSHARK_CACHE_DIR="..."
```

Important flags:

```text
-g   global scalar variable
-ga  global array
```

Examples:

```zsh
typeset -g _tshark_cache_loaded=0

typeset -ga _tshark_fields_cache
typeset -ga _tshark_protocol_cache
```

The leading underscore is a convention used to reduce collisions with normal shell variables/functions.

## 4. Cache generation and loading

`_TSHARK_CACHE_DIR` is `${XDG_CACHE_HOME:-$HOME/.cache}/tshark-completion`.
The `current` file contains the name of one immutable `generation.XXXXXXXX`
directory. Each generation contains `fields`, `protocols`, and `version`.

`_tshark_build_cache` creates a unique generation directory, captures
`tshark -G fields` separately so its exit status can be checked, and extracts
`F` records as `field.name:Description`. It derives distinct protocol prefixes
from the fields. Empty results or a failed TShark command are rejected.
Only after all three files are valid does it atomically replace the `current`
pointer file. Concurrent builders do not write into each other's directory.
A failed rebuild leaves the previous pointer intact. Old generations remain
on disk so a reader that resolved the previous pointer can finish safely;
removing the entire cache directory clears them when no completion is running.

`_tshark_ensure_persistent_cache` compares the active generation's version
with the first line of `tshark --version` and checks that both data files are
nonempty. `_tshark_load_cache` resolves the pointer once, then reads both files
into Zsh arrays. It sets `_tshark_cache_loaded=1` only after a successful load.
Subsequent completions in the same shell use those arrays without rechecking
TShark's version. `tshark-completion-refresh` builds a new generation first;
on failure, the existing cache and in-memory arrays stay available.

`-G`, `-F`, and `-T` use separate on-demand commands; they are not part of
this field cache. Their output parsers are covered by `tests/cache.zsh` with
representative command output.

## 5. `_tshark_fields`

This is the most important completion function.

```zsh
_tshark_fields() {
    _tshark_load_cache

    local prefix="$PREFIX"
    local field
    local -a matches
    ...
}
```

### 5.1 `$PREFIX`

`PREFIX` is supplied by Zsh's completion system and represents the text already typed in the current word.

Examples:

```text
tshark -Y <TAB>       → PREFIX=""
tshark -Y ip.<TAB>    → PREFIX="ip."
tshark -Y tcp.f<TAB>  → PREFIX="tcp.f"
```

### 5.2 Empty-prefix optimization

```zsh
if [[ -z "$prefix" ]]; then
    _describe 'protocol groups' _tshark_protocol_cache
    return
fi
```

`-z` tests whether a string is empty.

Instead of passing every Wireshark field to Zsh, the completion passes only protocol prefixes.

### 5.3 Prefix filtering

```zsh
matches=()

for field in "${_tshark_fields_cache[@]}"; do
    if [[ "$field" == "$prefix"* ]]; then
        matches+=("$field")
    fi
done
```

`for field in ...` iterates over each cached field.

The test:

```zsh
[[ "$field" == "$prefix"* ]]
```

means:

```text
does this field begin with the current prefix?
```

And:

```zsh
matches+=("$field")
```

appends it to the result array.

### 5.4 `_describe`

```zsh
_describe 'Wireshark fields' matches
```

is a Zsh completion helper that understands entries formatted as:

```text
value:description
```

So:

```text
ip.src:Source Address
```

can be presented as candidate `ip.src` with description `Source Address`.

## 6. Interface Completion

```zsh
_tshark_interfaces() {
    local -a interfaces

    interfaces=(
        "${(@f)$(tshark -D 2>/dev/null |
            sed -E 's/^([0-9]+)\. /\1:/')}"
    )

    _describe 'capture interfaces' interfaces
}
```

The source is:

```bash
tshark -D
```

Example raw output:

```text
1. enp3s0
2. wlan0
3. any
```

The `sed` expression:

```bash
sed -E 's/^([0-9]+)\. /\1:/'
```

changes:

```text
1. enp3s0
```

into:

```text
1:enp3s0
```

which fits `_describe`'s `value:description` convention.

## 7. Glossary Completion

```zsh
_tshark_glossaries() {
    local -a glossaries

    glossaries=(
        "${(@f)$(tshark -G help 2>/dev/null |
            awk 'NF { print $1 }')}"
    )

    _describe 'TShark glossary reports' glossaries
}
```

In AWK:

```text
NF = Number of Fields
```

Therefore:

```awk
NF { print $1 }
```

means:

```text
for every non-empty line, print the first field
```

## 8. Statistics Completion

The source is:

```bash
tshark -z help
```

The processing pipeline:

```zsh
awk '
    /^[[:space:]]*[a-zA-Z0-9_-]+/ {
        gsub(/^[[:space:]]+/, "")
        print $1
    }
' |
sed 's/,$//' |
sort -u
```

### Regular expression

```awk
/^[[:space:]]*[a-zA-Z0-9_-]+/
```

means roughly:

```text
start of line
optional whitespace
then an identifier
```

### `gsub`

```awk
gsub(/^[[:space:]]+/, "")
```

removes leading whitespace.

### `sed 's/,$//'`

removes a comma at the end of a result.

### `sort -u`

sorts and removes duplicates.

## 9. Capture File Format Completion

`_tshark_file_formats` follows the same general pattern:

```text
run TShark
    ↓
extract useful tokens
    ↓
convert lines to a Zsh array
    ↓
_describe
```

Understanding this pattern makes it easy to add new dynamic completion sources.

## 10. Static BPF Completion

The BPF list is stored as an array:

```zsh
typeset -ga _tshark_bpf_keywords=(
    'tcp:TCP packets'
    ...
)
```

Each entry follows:

```text
candidate:description
```

The completion function is intentionally simple:

```zsh
_tshark_capture_filter() {
    _describe 'BPF capture filter syntax' _tshark_bpf_keywords
}
```

This is an example of when a static dataset is preferable to a dynamic shell pipeline.

## 11. Dynamic `-T` Output Formats

`_tshark_output_formats` invokes `tshark -T __invalid__` and parses the
supported format names in TShark's diagnostic output. This source is dynamic
but sensitive to changes in that diagnostic format. Keep its fixture test
current when supporting another TShark version.

## 12. `_arguments`

The bottom of the file connects TShark options to completion functions.

Example:

```zsh
'-Y[apply Wireshark display filter]:display filter:_tshark_fields'
```

Read it as:

```text
-Y
│
├── description:
│   apply Wireshark display filter
│
└── argument:
    display filter
       │
       └── completion function:
           _tshark_fields
```

### 12.1 File completion

```zsh
'-r[read packets from capture file]:capture file:_files'
```

uses Zsh's built-in `_files` completion helper.

Therefore:

```bash
tshark -r <TAB>
```

shows filesystem candidates.

### 12.2 Repeatable options

```zsh
'*-e[...]'
```

The leading `*` means the option may occur multiple times.

Likewise:

```zsh
'*-z[...]'
```

This matches legitimate TShark usage where multiple `-e` or `-z` arguments can appear.

## 13. Common Patterns for Extending the Script

### Pattern A — Static completion

When an option has a small stable vocabulary:

```zsh
typeset -ga _my_values=(
    'foo:description'
    'bar:description'
)

_my_completion() {
    _describe 'values' _my_values
}
```

Then:

```zsh
'-X[description]:value:_my_completion'
```

### Pattern B — Dynamic completion from TShark

```zsh
_my_completion() {
    local -a values

    values=(
        "${(@f)$(tshark SOME_COMMAND 2>/dev/null |
            awk '...')}"
    )

    _describe 'values' values
}
```

Use this when TShark can enumerate the information reliably.

### Pattern C — Expensive dynamic completion

For expensive datasets:

```text
TShark command
    ↓
persistent cache
    ↓
RAM array
    ↓
filter by PREFIX
    ↓
_describe
```

This is the model currently used for fields.

## 14. How to Add Another TShark Option

Suppose a future option `-X` accepts a small set of values.

Create:

```zsh
typeset -ga _tshark_x_values=(
    'one:first mode'
    'two:second mode'
)

_tshark_x() {
    _describe 'X mode' _tshark_x_values
}
```

Then add to `_arguments`:

```zsh
'-X[select X mode]:mode:_tshark_x'
```

That is the basic extension workflow.

## 15. How to Debug the Completion

Confirm the completion function being used:

```bash
whence -v _tshark
```

Inspect completion search path:

```bash
print -l $fpath
```

Rebuild Zsh completion metadata:

```bash
rm -f ~/.zcompdump*
exec zsh
```

Verify TShark data sources manually:

```bash
tshark -G fields
tshark -G help
tshark -z help
tshark -D
tshark -F
```

Inspect cache:

```bash
ls -lh ~/.cache/tshark-completion
```

Force cache refresh:

```bash
tshark-completion-refresh
```

## 16. Things to Be Careful With

### Quoting

Prefer:

```zsh
"$variable"
"${array[@]}"
```

unless you deliberately want shell word splitting.

Completion code is especially sensitive to incorrect splitting.

### Global state

Anything declared with:

```zsh
typeset -g
typeset -ga
```

persists in the shell.

Choose unique names to avoid collisions.

### External commands inside completion

Every external command triggered during `<TAB>` can add latency.

For large datasets, prefer cache + RAM.

### Huge candidate sets

Even when generating candidates is fast, passing tens of thousands of entries to Zsh can itself be slow.

That is why empty `-Y` completion returns protocol groups instead of every field.

## 17. Current Technical Boundaries

The current implementation is deliberately **not**:

- a Wireshark display-filter parser;
- a BPF parser;
- a complete reimplementation of TShark's CLI grammar;
- a plugin/dissector manager;
- a replacement for `tshark --help`.

It is a pragmatic completion layer built around TShark's own introspection commands.

That scope keeps the implementation understandable and makes future extensions incremental rather than requiring a large parser framework.
