![Work in progress](assets/wip-banner.svg)

# TShark Zsh Completion

Context-aware tab completion for [TShark](https://www.wireshark.org/docs/man-pages/tshark.html) in Zsh.

It helps you discover TShark options, capture interfaces, output formats, statistics and Wireshark fields directly from the command line. Most suggestions are generated from **your installed TShark**, so completions stay aligned with its version and available dissectors.

```sh
tshark -Y ip.<TAB>   # Wireshark fields
tshark -T <TAB>      # output formats
tshark -i <TAB>      # capture interfaces
```

Also supported: `-e`, `-G`, `-z`, `-F`, basic `-f` capture filter keywords, and file completion for `-r` and `-w`.

## Installation

### Requirements

* Zsh
* TShark available on `PATH`
* Standard Unix utilities such as `awk`, `sed`, `sort`, `grep` and `mktemp`

```sh
git clone https://github.com/bcasasus/tshark-zsh-completion.git
cd tshark-zsh-completion
sh install.sh
exec zsh
```

The installer places `_tshark` in:

```text
${ZDOTDIR:-$HOME}/.zsh/completions
```

and configures that directory in your Zsh `fpath`. Existing installations can be safely updated by running the installer again.

Test it in a new Zsh session:

```sh
tshark -<TAB>
```

If Zsh still loads an older completion:

```sh
rm -f "${ZDOTDIR:-$HOME}"/.zcompdump*
exec zsh
```

### Manual installation

Copy `_tshark` to a directory in your Zsh `fpath`, for example:

```text
~/.zsh/completions/_tshark
```

Then add this before `compinit` or your plugin manager in `.zshrc`:

```zsh
fpath=(~/.zsh/completions $fpath)
```

If completion is not already initialized:

```zsh
autoload -Uz compinit
compinit
```

Restart Zsh.

## Supported systems

Designed for:

* Linux
* macOS
* WSL with Zsh and TShark

Other Unix-like systems may also work if the required commands are available.

This is a **Zsh-only** completion and does not support Bash, Fish, PowerShell or native Windows shells.

## How it works

Wireshark fields for `-Y` and `-e` are generated from:

```sh
tshark -G fields
```

To avoid displaying thousands of candidates at once, completion first suggests protocol prefixes such as:

```text
ip.
tcp.
http.
dns.
```

Typing a prefix then narrows the available fields.

Generated data is cached under:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/tshark-completion
```

The cache is automatically rebuilt when the installed TShark version changes.

To rebuild it manually:

```zsh
tshark-completion-refresh
```

The project currently covers a useful subset of TShark and does not yet parse complete Wireshark display filter expressions or full BPF syntax.

See the [architecture and limitations](docs/architecture.md), [technical guide](docs/technical-guide.md), and [roadmap](docs/ROADMAP.md) for more details.

## Uninstall

Remove:

```text
${ZDOTDIR:-$HOME}/.zsh/completions/_tshark
```

Then delete the block between:

```text
# >>> tshark-zsh-completion >>>
# <<< tshark-zsh-completion <<<
```

from `.zshrc`.

Optionally remove the cache:

```sh
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/tshark-completion"
```

## License

[MIT](LICENSE)
