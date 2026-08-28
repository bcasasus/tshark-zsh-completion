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

## 4. Cache Paths

The cache directory is defined as:

```zsh
typeset -g _TSHARK_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tshark-completion"
```

The syntax:

```zsh
${XDG_CACHE_HOME:-$HOME/.cache}
```

means:

```text
if XDG_CACHE_HOME has a value:
    use it
otherwise:
    use $HOME/.cache
```

Three files are derived from it:

```zsh
typeset -g _TSHARK_FIELDS_FILE="$_TSHARK_CACHE_DIR/fields"
typeset -g _TSHARK_PROTOCOLS_FILE="$_TSHARK_CACHE_DIR/protocols"
typeset -g _TSHARK_VERSION_FILE="$_TSHARK_CACHE_DIR/version"
```

## 5. `_tshark_current_version`

```zsh
_tshark_current_version() {
    tshark --version 2>/dev/null | head -n 1
}
```

This returns only the first line of `tshark --version`.

### `2>/dev/null`

Redirects standard error to `/dev/null`, preventing warnings from polluting completion output.

### `| head -n 1`

Keeps only the first line, producing a compact version identifier for cache invalidation.

## 6. `_tshark_build_cache`

This function generates persistent data.

### 6.1 Create cache directory

```zsh
mkdir -p "$_TSHARK_CACHE_DIR"
```

`-p` creates missing parent directories and does not fail if the directory already exists.

### 6.2 Temporary files

```zsh
local tmp_fields="$_TSHARK_FIELDS_FILE.tmp"
local tmp_protocols="$_TSHARK_PROTOCOLS_FILE.tmp"
local tmp_version="$_TSHARK_VERSION_FILE.tmp"
```

`local` limits these variables to the function.

Temporary files allow this pattern:

```text
generate .tmp
    ↓
finish successfully
    ↓
mv .tmp final-file
```

This is safer than writing directly into the active cache.

## 7. Parsing `tshark -G fields`

The core generation pipeline is:

```zsh
tshark -G fields 2>/dev/null |
    awk -F '\t' '
        $1 == "F" {
            print $3 ":" $2
        }
    ' > "$tmp_fields"
```

### 7.1 `tshark -G fields`

Returns TShark/Wireshark's registered protocol and field information.

The output is tab-separated.

### 7.2 `awk -F '\t'`

`-F` sets AWK's input field separator.

Here it means:

```text
split each line on TAB characters
```

AWK exposes fields as:

```text
$1
$2
$3
...
```

### 7.3 `$1 == "F"`

The condition:

```awk
$1 == "F"
```

keeps only records representing actual fields.

### 7.4 `print $3 ":" $2`

Builds:

```text
field.name:Description
```

For example:

```text
ip.src:Source Address
tcp.stream:Stream index
dns.qry.name:Query Name
```

This is useful because Zsh `_describe` understands `value:description` pairs.

## 8. Building the Protocol Cache

The second pipeline reads the fields file:

```zsh
awk -F ':' '
    {
        split($1, parts, ".")
        if (parts[1] != "")
            print parts[1] "."
    }
' "$tmp_fields" |
    sort -u > "$tmp_protocols"
```

Suppose the fields file contains:

```text
ip.src:Source Address
ip.dst:Destination Address
tcp.srcport:Source Port
tcp.dstport:Destination Port
```

Using `-F ':'` gives:

```text
$1 = ip.src
```

Then:

```awk
split($1, parts, ".")
```

creates:

```text
parts[1] = ip
parts[2] = src
```

and prints:

```text
ip.
```

Because there are many duplicates, `sort -u` sorts and removes them.

This compact protocol list is what makes empty `-Y <TAB>` completion fast.

## 9. Storing the Version

```zsh
_tshark_current_version > "$tmp_version"
```

writes the current version to a temporary file.

Then:

```zsh
mv "$tmp_fields" "$_TSHARK_FIELDS_FILE"
mv "$tmp_protocols" "$_TSHARK_PROTOCOLS_FILE"
mv "$tmp_version" "$_TSHARK_VERSION_FILE"
```

promotes all completed temporary files to the active cache.

## 10. `_tshark_ensure_persistent_cache`

This decides whether cache generation is necessary.

```zsh
local current_version="$(_tshark_current_version)"
local cached_version=""
```

### Command substitution

```zsh
$(_tshark_current_version)
```

runs the function and inserts its output.

### Reading a file with Zsh

```zsh
cached_version="$(<$_TSHARK_VERSION_FILE)"
```

is a Zsh shortcut for reading a file without starting an external `cat` process.

### Cache validity test

```zsh
if [[ ! -s "$_TSHARK_FIELDS_FILE" ]] ||
   [[ ! -s "$_TSHARK_PROTOCOLS_FILE" ]] ||
   [[ "$cached_version" != "$current_version" ]]
then
    _tshark_build_cache
fi
```

`-s file` means the file exists and has a size greater than zero.

The cache is rebuilt when:

- `fields` is absent or empty;
- `protocols` is absent or empty;
- the cached TShark version differs from the current one.

## 11. `_tshark_load_cache`

This loads persistent data into RAM.

```zsh
if (( _tshark_cache_loaded )); then
    return
fi
```

`(( ... ))` is Zsh arithmetic context. A non-zero value is true.

So this means:

```text
if already loaded:
    stop immediately
```

### Reading file lines into arrays

```zsh
_tshark_fields_cache=(
    "${(@f)$(<$_TSHARK_FIELDS_FILE)}"
)
```

This is Zsh-specific syntax.

Conceptually:

```text
$(<file)  → read file
(@f)      → split on newlines into array elements
```

A file containing:

```text
ip.src:Source Address
ip.dst:Destination Address
```

becomes conceptually:

```zsh
_tshark_fields_cache=(
    'ip.src:Source Address'
    'ip.dst:Destination Address'
)
```

Finally:

```zsh
_tshark_cache_loaded=1
```

marks the in-memory cache as ready.

## 12. Manual Refresh Function

```zsh
tshark-completion-refresh() {
    ...
}
```

This function intentionally does not start with `_` because it is meant to be executed directly by the user.

The sequence is:

```zsh
rm -rf "$_TSHARK_CACHE_DIR"
```

Delete persistent cache.

```zsh
_tshark_fields_cache=()
_tshark_protocol_cache=()
_tshark_cache_loaded=0
```

Reset RAM state.

Then:

```zsh
_tshark_build_cache
_tshark_load_cache
```

rebuild and immediately reload the cache.

## 13. `_tshark_fields`

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

### 13.1 `$PREFIX`

`PREFIX` is supplied by Zsh's completion system and represents the text already typed in the current word.

Examples:

```text
tshark -Y <TAB>       → PREFIX=""
tshark -Y ip.<TAB>    → PREFIX="ip."
tshark -Y tcp.f<TAB>  → PREFIX="tcp.f"
```

### 13.2 Empty-prefix optimization

```zsh
if [[ -z "$prefix" ]]; then
    _describe 'protocol groups' _tshark_protocol_cache
    return
fi
```

`-z` tests whether a string is empty.

Instead of passing every Wireshark field to Zsh, the completion passes only protocol prefixes.

### 13.3 Prefix filtering

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

### 13.4 `_describe`

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

## 14. Interface Completion

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

## 15. Glossary Completion

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

## 16. Statistics Completion

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

## 17. Capture File Format Completion

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

## 18. Static BPF Completion

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

## 19. Static `-T` Output Formats

The same pattern is used for output formats:

```zsh
typeset -ga _tshark_output_formats=(...)
```

then:

```zsh
_tshark_output_format() {
    _describe 'output format' _tshark_output_formats
}
```

## 20. `_arguments`

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

### 20.1 File completion

```zsh
'-r[read packets from capture file]:capture file:_files'
```

uses Zsh's built-in `_files` completion helper.

Therefore:

```bash
tshark -r <TAB>
```

shows filesystem candidates.

### 20.2 Repeatable options

```zsh
'*-e[...]'
```

The leading `*` means the option may occur multiple times.

Likewise:

```zsh
'*-z[...]'
```

This matches legitimate TShark usage where multiple `-e` or `-z` arguments can appear.

## 21. Common Patterns for Extending the Script

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

## 22. How to Add Another TShark Option

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

## 23. How to Debug the Completion

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

## 24. Things to Be Careful With

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

## 25. Current Technical Boundaries

The current implementation is deliberately **not**:

- a Wireshark display-filter parser;
- a BPF parser;
- a complete reimplementation of TShark's CLI grammar;
- a plugin/dissector manager;
- a replacement for `tshark --help`.

It is a pragmatic completion layer built around TShark's own introspection commands.

That scope keeps the implementation understandable and makes future extensions incremental rather than requiring a large parser framework.
