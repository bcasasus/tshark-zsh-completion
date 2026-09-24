# TShark Zsh Completion Roadmap

## Goal

The long-term goal of this project is to evolve `_tshark` from a useful standalone completion into a high-quality, maintainable Zsh completion suitable for contribution to [`zsh-users/zsh-completions`](https://github.com/zsh-users/zsh-completions), and potentially later to Zsh itself.

The project should aim to provide:

- Broad TShark CLI coverage.
- Dynamic completions based on the user's installed TShark version.
- Fast field and protocol completion.
- Context-aware completion for complex arguments such as display filters.
- Idiomatic use of the Zsh completion framework.
- Good maintainability, testability, and resilience across TShark versions.

A key design principle is:

> Prefer structured information exposed by TShark over hardcoded data.

---

# Current strengths

The current implementation already provides several important foundations:

- Dynamic Wireshark field discovery using `tshark -G fields`.
- Protocol group extraction.
- Persistent cache with version-based invalidation.
- In-memory cache for faster repeated completion.
- Dynamic interface completion with `tshark -D`.
- Dynamic glossary completion with `tshark -G`.
- Dynamic statistics completion with `tshark -z help`.
- Dynamic capture format completion with `tshark -F`.
- Dynamic output format completion with `tshark -T`.
- Basic BPF capture filter completion.
- Integration with `_arguments` and `_describe`.

The main architectural direction is therefore sound. The roadmap focuses on making it more native to Zsh, more complete, and more scalable.

---

# v0.2 — Native Zsh architecture

## Objective

Refactor the completion so that its internal architecture follows established Zsh completion patterns before adding more features.

## Tasks

- [ ] Change the main completion to use `_arguments -C`.
- [ ] Introduce completion state handling using:
  - `context`
  - `state`
  - `state_descr`
  - `line`
- [ ] Introduce `typeset -A opt_args`.
- [ ] Replace direct program execution where appropriate with `_call_program`.
- [ ] Reduce global mutable state.
- [ ] Review all helper function naming and visibility.
- [ ] Investigate replacing or integrating the custom cache with:
  - `_cache_invalid`
  - `_retrieve_cache`
  - `_store_cache`
- [ ] Preserve TShark-version-based invalidation where useful.
- [ ] Add graceful handling when `tshark` is unavailable.
- [ ] Prevent failed TShark commands from generating invalid or empty cache files.
- [ ] Remove or redesign `tshark-completion-refresh` if native cache handling makes it unnecessary.
- [ ] Normalize comments and file structure to resemble established Zsh completion files.

## Acceptance criteria

- Completion behavior remains functionally equivalent to the current version.
- No regressions for:
  - `-Y`
  - `-e`
  - `-i`
  - `-G`
  - `-z`
  - `-F`
  - `-T`
  - `-f`
- TShark command execution is isolated behind reusable helpers.
- Cache failures cannot silently corrupt completion state.
- The main `_tshark` function is ready to support context-driven completion.

---

# v0.3 — Field engine and lazy loading

## Objective

Redesign field completion so that `_tshark` does not need to load or scan the complete Wireshark field database on every relevant completion.

This phase takes inspiration from protocol-partitioned approaches while keeping the important advantage of dynamically generating data from the user's installed TShark.

## Target architecture

```text
tshark -G fields
       |
       v
cache generation
       |
       +-- protocol index
       |
       +-- fields grouped by protocol
              |
              +-- tcp
              +-- http
              +-- dns
              +-- ip
              +-- tls
              +-- ...
```

## Tasks

- [ ] Generate a protocol index from `tshark -G fields`.
- [ ] Group fields by protocol.
- [ ] Avoid loading all fields into RAM at once.
- [ ] Load only the protocol group needed by the current prefix.
- [ ] Keep descriptions alongside fields where practical.
- [ ] Ensure `tshark -Y <TAB>` completes protocol groups.
- [ ] Ensure `tshark -Y tcp.<TAB>` loads only TCP-related fields.
- [ ] Reuse the same field engine for `-e`.
- [ ] Benchmark:
  - first completion
  - cached completion
  - protocol completion
  - field completion
- [ ] Avoid arbitrary result limits that hide valid candidates.

## Acceptance criteria

- Completing `tcp.`, `http.`, `dns.`, etc. does not require scanning every Wireshark field.
- The completion remains dynamic across TShark versions.
- No generated field database is committed to the repository.
- Repeated completion feels effectively instantaneous on a warm cache.

---

# v0.4 — Full TShark CLI coverage

## Objective

Move from partial option support to a broadly complete TShark command-line completion.

This is important for upstream readiness because a partially implemented completion is less likely to be accepted.

## Tasks

Create and maintain an option inventory based on the current TShark help and manual.

### Capture

- [ ] `-i`
- [ ] `-f`
- [ ] `-s`
- [ ] `-p`
- [ ] `-I`
- [ ] `-B`
- [ ] `-y`
- [ ] `-D`
- [ ] `-L`

### Input and filtering

- [ ] `-r`
- [ ] `-2`
- [ ] `-R`
- [ ] `-Y`

### Output

- [ ] `-w`
- [ ] `-F`
- [ ] `-T`
- [ ] `-e`
- [ ] `-E`
- [ ] `-x`
- [ ] `-V`
- [ ] `-O`
- [ ] `-P`

### Name resolution

- [ ] `-n`
- [ ] `-N`

### Dissection and protocols

- [ ] `-d`
- [ ] `-K`
- [ ] `--enable-protocol`
- [ ] `--disable-protocol`
- [ ] `--only-protocols`

### Statistics

- [ ] `-z`

### Preferences and profiles

- [ ] `-o`
- [ ] `-C`

### Time formatting

- [ ] `-t`
- [ ] `-u`

### General and miscellaneous

- [ ] `-G`
- [ ] `-h`
- [ ] `-v`
- [ ] `-q`
- [ ] `-Q`
- [ ] Review all remaining short and long options.

## Acceptance criteria

- All commonly documented TShark options appear in completion.
- Boolean flags provide descriptions.
- File arguments use `_files`.
- Directory arguments use appropriate Zsh helpers.
- Numeric arguments are described appropriately.
- Enumerated options use `_values`, `_describe`, or equivalent helpers.
- Long options are covered where supported by TShark.

---

# v0.5 — Context-aware display filters

## Objective

Make `-Y` completion useful inside real Wireshark display filter expressions rather than only when completing a simple field prefix.

## Examples

```sh
tshark -Y 'tcp.<TAB>'
```

Should complete TCP fields.

```sh
tshark -Y 'tcp.port == 80 && http.<TAB>'
```

Should preserve the existing expression and complete HTTP fields.

```sh
tshark -Y 'tcp.port <TAB>'
```

Should suggest relevant operators.

## Initial operator set

- `==`
- `!=`
- `>`
- `<`
- `>=`
- `<=`
- `contains`
- `matches`
- `in`
- `&&`
- `||`
- `and`
- `or`
- `not`

## Tasks

- [ ] Extract the active token from the current display filter expression.
- [ ] Preserve the expression prefix when inserting completions.
- [ ] Detect when the current token is:
  - a protocol
  - a field
  - an operator position
  - a logical continuation
- [ ] Use `compadd` where finer prefix/suffix control is necessary.
- [ ] Continue using higher-level Zsh helpers where possible.
- [ ] Avoid building a complete Wireshark filter parser in v1.0.
- [ ] Support quoted display filter arguments correctly.

## Acceptance criteria

The following forms work reliably:

```sh
tshark -Y '<protocol><TAB>'
tshark -Y '<protocol>.<TAB>'
tshark -Y '<field> <TAB>'
tshark -Y '<expression> && <protocol>.<TAB>'
```

---

# v0.6 — Advanced argument grammars

## Objective

Add context-sensitive completion for TShark options whose values contain their own mini-language or multi-part syntax.

---

## `-E`

Support field-output configuration.

Examples:

```sh
tshark -T fields -E <TAB>
```

Possible keys may include:

- `aggregator`
- `bom`
- `escape`
- `header`
- `occurrence`
- `quote`
- `separator`

And nested completion such as:

```sh
tshark -E header=<TAB>
```

with:

```text
y
n
```

---

## `-O`

Complete protocols and comma-separated protocol lists.

Example:

```sh
tshark -O tcp,http,<TAB>
```

Use the dynamic protocol database.

---

## Protocol control options

Support:

```sh
--enable-protocol
--disable-protocol
--only-protocols
```

with dynamic protocol completion.

Where appropriate, support comma-separated values.

---

## `-N`

Complete name-resolution flags with descriptions.

---

## `-z`

Start with first-level statistics completion, then incrementally support nested forms such as:

```text
follow,...
conv,...
endpoints,...
flow,...
expert,...
io,stat,...
```

Potential future example:

```sh
tshark -z follow,<TAB>
```

followed by protocol and mode completion.

---

## `-d`

Provide first-level Decode As completion.

Long-term target:

```sh
tshark -d tcp.port==8888,<TAB>
```

with protocol suggestions.

This should only be implemented as far as it remains maintainable.

## Acceptance criteria

- `-E`, `-O`, protocol control options, and `-N` provide useful contextual completion.
- `-z` and `-d` have at least useful first-level completion.
- Nested grammars do not make the implementation disproportionately complex.

---

# v0.7 — Reliability, testing, and compatibility

## Objective

Make the completion robust enough for external users and upstream review.

## Functional test matrix

At minimum, verify:

| Command | Expected completion |
|---|---|
| `tshark -<TAB>` | CLI options |
| `tshark -r <TAB>` | files |
| `tshark -w <TAB>` | files |
| `tshark -i <TAB>` | interfaces |
| `tshark -Y <TAB>` | protocol groups |
| `tshark -Y tcp.<TAB>` | TCP fields |
| `tshark -e ip.<TAB>` | IP fields |
| `tshark -G <TAB>` | glossary/report types |
| `tshark -F <TAB>` | capture formats |
| `tshark -T <TAB>` | output formats |
| `tshark -z <TAB>` | statistics modules |
| `tshark -O <TAB>` | protocols |
| `tshark --only-protocols <TAB>` | protocols |

## Environment and failure cases

- [ ] Cold cache.
- [ ] Warm cache.
- [ ] Stale cache after TShark upgrade.
- [ ] Custom `XDG_CACHE_HOME`.
- [ ] Missing TShark executable.
- [ ] Failed `tshark -G fields`.
- [ ] Empty command output.
- [ ] Multiple supported TShark versions.
- [ ] Different Linux distributions where practical.
- [ ] macOS if available.
- [ ] Zsh versions commonly used by target systems.

## Performance checks

Measure:

- [ ] Initial cache generation.
- [ ] First completion after shell startup.
- [ ] Warm protocol completion.
- [ ] Warm field completion.
- [ ] Context-aware `-Y` completion.

## Acceptance criteria

- No corrupted cache is produced after a failed command.
- Normal warm completions feel immediate.
- No valid candidates are deliberately hidden for performance reasons.
- Behavior is consistent across the tested environments.

---

# v1.0 — Upstream-ready release

## Objective

Produce a stable `_tshark` implementation that can reasonably be proposed to `zsh-users/zsh-completions`.

## Required characteristics

- [ ] Broad TShark CLI coverage.
- [ ] Dynamic field and protocol discovery.
- [ ] Efficient field completion.
- [ ] Reasonable context awareness for `-Y`.
- [ ] Dynamic interface completion.
- [ ] Dynamic output and capture format completion.
- [ ] Statistics completion.
- [ ] Protocol completion for relevant arguments.
- [ ] Native Zsh completion architecture.
- [ ] Robust caching.
- [ ] Graceful failure behavior.
- [ ] Tested across multiple TShark versions.
- [ ] Clean and maintainable source.
- [ ] No unnecessary generated data in the repository.
- [ ] Documentation for contributors.
- [ ] Appropriate license for potential future inclusion in Zsh.

---

# Data-source policy

Whenever multiple ways exist to obtain completion data, prefer them in this order:

1. Structured information exposed by TShark.
2. Explicit help/listing modes.
3. Stable documented command output.
4. Parsing diagnostic/error output only as a last resort.

Examples:

```text
GOOD
tshark -G fields

GOOD
tshark -z help

ACCEPTABLE
tshark -F

LAST RESORT
triggering an invalid argument only to extract supported values
```

This keeps the completion resilient across releases.

---

# Shell parsing policy

Do not attempt to eliminate `awk` or `sed` simply for the sake of using pure Zsh.

Preferred division of responsibilities:

```text
Zsh
  -> completion state
  -> arrays
  -> context handling
  -> cache integration
  -> candidate generation

awk
  -> structured/tabular parsing when clearer than shell parameter expansion

sed
  -> small transformations where it remains readable
```

Readability and maintainability are more important than avoiding external text-processing tools entirely.

---

# Scope for v1.0

The project should avoid overengineering before the first upstream-ready version.

## In scope

- Full or near-full CLI option coverage.
- Dynamic protocols and fields.
- Efficient field lookup.
- Context-aware display filter completion.
- Common nested arguments.
- Good performance and reliability.

## Explicitly optional for v1.0

- A complete Wireshark display filter parser.
- Full grammar support for every `-z` statistics module.
- Full Decode As grammar.
- Semantic completion of filter values such as live IP addresses or ports.
- Complex packet-aware completion.

These can be considered for `v1.1+`.

---

# Possible post-v1.0 work

## v1.1+

Potential improvements:

- Deeper `-z` completion.
- Better `-d` completion.
- More accurate display filter grammar awareness.
- Field-type-aware operators.
- Preference completion for `-o`.
- Profile completion for `-C`.
- Additional context-sensitive values.
- Automated compatibility testing against multiple TShark releases.

---

# Upstream strategy

The preferred target is:

```text
zsh-users/zsh-completions
```

The project should be developed with that target in mind.

Before proposing upstream:

- Review the current contribution guidelines.
- Compare `_tshark` against accepted completion files of similar complexity.
- Remove project-specific behavior that does not belong in a shared completion.
- Ensure option coverage is not obviously partial.
- Keep dependencies minimal.
- Use native Zsh completion helpers where appropriate.
- Document any intentional limitations.
- Confirm licensing compatibility.

A later move from `zsh-users/zsh-completions` into Zsh itself could be considered if the completion becomes mature, widely used, and maintainable enough.

---

# Design objective

The final architecture should approximately follow this model:

```text
                         _tshark
                            |
                    _arguments -C
                            |
             +--------------+--------------+
             |              |              |
            -Y             -z             -E
             |              |              |
             v              v              v
      display-filter     statistics     key/value
         context           context       context
             |
             v
       field engine
             |
      +------+------+
      |             |
 protocol index   per-protocol fields
      |             |
      +------ cache-+
             |
      dynamic TShark data
             |
      _call_program / tshark
```

The target is not merely to provide autocomplete for a few TShark arguments.

The target is to provide a **complete, dynamic, efficient, and maintainable native Zsh completion for TShark**.
