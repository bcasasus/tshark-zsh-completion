# TShark Zsh Completion — Features, Architecture and Limitations

## 1. Purpose

This completion extends Zsh autocomplete for `tshark` with contextual suggestions for common TShark options.

The main goals are:

- Make TShark easier to discover from the terminal.
- Reuse information exposed by TShark itself whenever possible.
- Avoid hardcoding large lists of Wireshark fields.
- Keep autocomplete fast despite the very large number of registered Wireshark fields.
- Keep the implementation simple enough to maintain and extend.

The completion is installed as a native Zsh completion file:

```text
~/.zsh/completions/_tshark
```

and loaded through Zsh's normal `fpath` + `compinit` mechanism.

## 2. Current Features

### 2.1 Main TShark option completion

Typing:

```bash
tshark -<TAB>
```

provides descriptions for the currently implemented options:

```text
-r
-w
-Y
-f
-e
-T
-i
-z
-G
-F
-q
-V
-D
```

This is implemented through Zsh's `_arguments` helper.

### 2.2 Display filter field completion: `-Y`

Example:

```bash
tshark -Y <TAB>
```

Instead of displaying every Wireshark field, the completion initially displays protocol groups such as:

```text
ip.
tcp.
udp.
dns.
http.
tls.
...
```

This is an important performance optimization.

After entering a prefix:

```bash
tshark -Y ip.<TAB>
```

the completion searches the cached Wireshark fields and returns only matching fields, for example:

```text
ip.addr
ip.dst
ip.flags
ip.len
ip.proto
ip.src
ip.ttl
...
```

The field database comes from:

```bash
tshark -G fields
```

so the suggestions correspond to the fields registered by the installed TShark/Wireshark version.

### 2.3 Field completion for `-T fields -e`

The same field database is reused for field extraction:

```bash
tshark -T fields -e <TAB>
```

and:

```bash
tshark -T fields -e tcp.<TAB>
```

Because `-e` may be used multiple times, the completion declares it as repeatable.

Example:

```bash
tshark -r capture.pcapng \
  -T fields \
  -e ip.src \
  -e ip.dst \
  -e tcp.dstport
```

### 2.4 Persistent field cache

`tshark -G fields` can be relatively expensive and produces a very large amount of output.

The completion therefore stores generated data under:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/tshark-completion/
```

Normally:

```text
~/.cache/tshark-completion/
├── fields
├── protocols
└── version
```

#### `fields`

Contains entries generated from `tshark -G fields` in the form:

```text
ip.src:Source Address
ip.dst:Destination Address
tcp.stream:Stream index
...
```

#### `protocols`

Contains protocol prefixes derived from the field database:

```text
ip.
tcp.
udp.
dns.
http.
...
```

#### `version`

Stores the first line of:

```bash
tshark --version
```

This is used to detect TShark upgrades.

### 2.5 Automatic cache invalidation

Before loading the persistent cache, the completion compares:

```text
cached TShark version
        vs
current TShark version
```

If the version changed, the cache is rebuilt automatically.

This avoids keeping stale field data after a normal TShark/Wireshark upgrade.

### 2.6 In-memory cache

Persistent files avoid regenerating the field database between terminal sessions.

Once a Zsh session needs TShark fields, those files are loaded into global Zsh arrays:

```text
_tshark_fields_cache
_tshark_protocol_cache
```

From that point onward, field completion within the same shell session works from RAM.

The resulting flow is:

```text
TShark
  │
  │ tshark -G fields
  │ only when cache must be built
  ▼
Persistent cache
~/.cache/tshark-completion/
  │
  │ once per Zsh session
  ▼
Zsh arrays in RAM
  │
  ▼
<TAB> completion
```

This combines persistence between sessions with fast access during a session.

### 2.7 Manual cache refresh

The completion provides:

```bash
tshark-completion-refresh
```

This:

1. Deletes the persistent cache.
2. Clears the in-memory arrays.
3. Runs `tshark -G fields` again.
4. Recreates the protocol list.
5. Stores the current TShark version.
6. Reloads everything into RAM.

This is especially useful after installing a dissector or plugin without changing the TShark version.

### 2.8 Capture interface completion: `-i`

Typing:

```bash
tshark -i <TAB>
```

uses:

```bash
tshark -D
```

to retrieve the interfaces currently visible to TShark.

This means the list is generated dynamically rather than hardcoded.

### 2.9 TShark glossary completion: `-G`

Typing:

```bash
tshark -G <TAB>
```

uses:

```bash
tshark -G help
```

to retrieve the glossary/report types supported by the installed version.

### 2.10 Statistics completion: `-z`

Typing:

```bash
tshark -z <TAB>
```

uses:

```bash
tshark -z help
```

to generate the list of available statistics modules.

The `-z` option is marked as repeatable because TShark can execute multiple statistics taps in one command.

### 2.11 Capture file format completion: `-F`

Typing:

```bash
tshark -F <TAB>
```

uses TShark output to retrieve supported capture file formats dynamically.

### 2.12 Output format completion: `-T`

Typing:

```bash
tshark -T <TAB>
```

uses a small static list:

```text
text
fields
json
jsonraw
ek
pdml
psml
tabs
```

Each entry includes a human-readable description.

### 2.13 Basic capture-filter completion: `-f`

Typing:

```bash
tshark -f <TAB>
```

provides a small static vocabulary for common libpcap/BPF capture-filter syntax:

```text
tcp
udp
icmp
icmp6
ip
ip6
arp
ether

host
net
port
portrange

src
dst

and
or
not

less
greater

broadcast
multicast
```

This is intentionally simple.

`-f` does **not** use Wireshark display-filter fields. It belongs to the libpcap/BPF capture-filter language, which is separate from the display-filter language used by `-Y`.

## 3. Architecture

The completion can be divided into five logical layers.

```text
┌──────────────────────────────────────┐
│ 1. Zsh completion interface         │
│    _arguments / _describe           │
└─────────────────┬────────────────────┘
                  │
┌─────────────────▼────────────────────┐
│ 2. Context-specific completion      │
│    -Y/-e  -i  -G  -z  -F  -f  -T   │
└─────────────────┬────────────────────┘
                  │
┌─────────────────▼────────────────────┐
│ 3. In-memory field cache            │
│    Zsh arrays                        │
└─────────────────┬────────────────────┘
                  │
┌─────────────────▼────────────────────┐
│ 4. Persistent cache                 │
│    ~/.cache/tshark-completion/      │
└─────────────────┬────────────────────┘
                  │
┌─────────────────▼────────────────────┐
│ 5. TShark / Unix utilities          │
│    tshark, awk, sed, sort, head     │
└──────────────────────────────────────┘
```

### Layer 1 — Zsh

The bottom of the completion file calls `_arguments`, which maps TShark options to the functions responsible for completing their values.

### Layer 2 — Completion functions

Examples:

```text
_tshark_fields
_tshark_interfaces
_tshark_glossaries
_tshark_statistics
_tshark_file_formats
_tshark_capture_filter
_tshark_output_format
```

### Layer 3 — RAM

Large field lists are loaded into Zsh arrays only once per shell session.

### Layer 4 — Persistent cache

Generated field information survives terminal restarts.

### Layer 5 — Data sources

Whenever possible, the completion asks the installed `tshark` binary for the available information.

## 4. Dynamic vs Static Data

### Dynamic

Generated from the installed TShark:

```text
-Y / -e   tshark -G fields
-i        tshark -D
-G        tshark -G help
-z        tshark -z help
-F        tshark -F
```

Advantages:

- Adapts to installed TShark version.
- Adapts to available dissectors.
- Requires less manual maintenance.
- Avoids maintaining huge hardcoded databases.

### Static

Currently hardcoded:

```text
-T output formats
-f common BPF keywords
```

These datasets are small enough that static definitions keep the completion simple.

## 5. Performance Strategy

The biggest performance problem is the number of registered Wireshark fields.

Displaying every field for:

```bash
tshark -Y <TAB>
```

causes Zsh to process a huge candidate list.

The completion avoids that through two mechanisms.

### 5.1 Protocol-first completion

Empty `-Y` and `-e` values display protocol prefixes rather than every field.

```text
-Y <TAB>
   ↓
ip.
tcp.
udp.
dns.
...
```

Then:

```text
-Y ip.<TAB>
   ↓
only fields beginning with ip.
```

### 5.2 Two-level cache

```text
persistent disk cache
        +
in-memory Zsh cache
```

This prevents repeatedly running `tshark -G fields` and prevents repeatedly reading the large cache file within the same shell session.

## 6. Current Limitations

### 6.1 `-Y` is prefix completion, not a display-filter parser

The completion understands:

```bash
tshark -Y ip.<TAB>
```

but it does not parse arbitrary Wireshark expressions.

For example:

```bash
tshark -Y 'ip.src == 10.0.0.1 && tcp.<TAB>'
```

is not currently designed to understand that only `tcp.` is the active fragment.

### 6.2 No value-aware completion

The script knows field names such as:

```text
ip.src
tcp.flags.syn
http.request.method
```

but it does not inspect the field type to propose valid values.

### 6.3 Basic `-f` completion only

The capture-filter completion is a vocabulary list, not a BPF parser.

It can suggest:

```text
tcp
dst
port
and
...
```

but it does not understand the grammatical context of a complete expression.

### 6.4 Cache version detection does not detect all dissector changes

Automatic invalidation relies on:

```bash
tshark --version
```

If a new Lua/custom dissector is installed while the TShark version remains unchanged, the cache may become stale.

Solution:

```bash
tshark-completion-refresh
```

### 6.5 Some dynamic options are not cached

Currently the persistent cache is primarily used for the expensive field database.

Commands such as:

```bash
tshark -D
tshark -G help
tshark -z help
tshark -F
```

are executed when their completion is requested.

### 6.6 The completion does not cover every TShark option

Only a practical subset of TShark's CLI is currently declared in `_arguments`.

### 6.7 Unix command dependencies

The script currently expects common Unix utilities such as:

```text
awk
sed
sort
head
mv
mkdir
rm
```

## 7. Installation Requirements

Expected layout:

```text
~/.zsh/
└── completions/
    └── _tshark
```

Your `~/.zshrc` must add the completion directory to `fpath` **before `compinit` runs**:

```zsh
fpath=(~/.zsh/completions $fpath)

autoload -Uz compinit
compinit
```

When adding or changing the completion file, rebuilding the Zsh completion dump may be useful:

```bash
rm -f ~/.zcompdump*
exec zsh
```

## 8. Useful Maintenance Commands

Rebuild the TShark field cache:

```bash
tshark-completion-refresh
```

Inspect cached files:

```bash
ls -lh ~/.cache/tshark-completion
```

Inspect cached fields:

```bash
head ~/.cache/tshark-completion/fields
```

Search fields manually:

```bash
grep '^dns\.' ~/.cache/tshark-completion/fields
```

Inspect protocol prefixes:

```bash
cat ~/.cache/tshark-completion/protocols
```

Check cached version:

```bash
cat ~/.cache/tshark-completion/version
```

Compare with current version:

```bash
tshark --version | head -n 1
```

## 9. Good Future Extensions

Reasonable future improvements include:

1. Parse the active token inside complex `-Y` expressions.
2. Use field type information from `tshark -G fields`.
3. Add operator/value completion for display filters.
4. Improve BPF completion while keeping it maintainable.
5. Add more TShark command-line options to `_arguments`.
6. Cache other dynamic lists if profiling shows a real benefit.
7. Add completion for nested `-z` syntaxes such as `follow,tcp,...`.
8. Add tests for cache generation and completion helper functions.

The current architecture already separates the main concerns well enough to support these extensions without a full rewrite.
