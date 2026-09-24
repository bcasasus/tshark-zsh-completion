# TShark Zsh completion

Context-aware tab completion for [TShark](https://www.wireshark.org/docs/man-pages/tshark.html) in Zsh. It helps you discover command options, capture interfaces, output formats and Wireshark fields while typing commands. Most suggestions come from **your installed TShark**, so they follow its version and available dissectors.

For example, type `tshark -Y ip.<TAB>` to see available `ip` fields, or `tshark -T <TAB>` for output formats. You can also complete `-e` fields, `-i` interfaces, `-G` reports, `-z` statistics, `-F` capture file formats and a small set of `-f` capture filter keywords. File paths complete for `-r` and `-w`.

## Install

Requirements: **Zsh**, **TShark** on `PATH`, and standard Unix utilities (`awk`, `sed`, `sort`, `head`, `mkdir`, `mv`, `cp`, `grep`, `cmp`, `mktemp`).

```sh
git clone https://github.com/bcasasus/tshark-zsh-completion.git
cd tshark-zsh-completion
sh install.sh
exec zsh
```

The installer copies `_tshark` to `${ZDOTDIR:-$HOME}/.zsh/completions`, adds that directory to `fpath` near the top of `.zshrc` (before existing completion initialization), and initializes completion if your `.zshrc` does not already do so. It backs up a different existing `_tshark` file before replacing it. Re-running the installer updates the completion without duplicating the `fpath` entry.

Try `tshark -<TAB>` in a **new interactive Zsh** session. If your shell still uses an older completion, run `rm -f "${ZDOTDIR:-$HOME}"/.zcompdump*` and `exec zsh`.

### Manual install

Copy `_tshark` into a directory on your Zsh `fpath`. For example, copy it to `~/.zsh/completions/_tshark`, then put this **before** any `compinit` or plugin manager in `.zshrc`:

```zsh
fpath=(~/.zsh/completions $fpath)
```

If your configuration does not initialize Zsh completion yet, also add `autoload -Uz compinit; compinit` after that line. Restart Zsh.

## Supported systems

This is a **Zsh** completion, so it does not work in Bash, Fish or PowerShell. Its shell code and installer use Unix utilities. It is designed for Linux and macOS where Zsh and TShark are installed; it should also work on other Unix-like systems with those commands, but those systems have not been tested here. Native Windows is not supported; WSL with Zsh and TShark follows the Linux setup. The completion depends on TShark's help output, which can vary between versions, so some dynamic suggestions may vary too.

## How it works

For `-Y` and `-e`, the completion builds a list of registered Wireshark fields from `tshark -G fields`. To avoid showing thousands of suggestions at once, an empty value first offers protocol prefixes (`ip.`, `tcp.`, etc.); typing a prefix narrows the list. The fields are cached on disk under `${XDG_CACHE_HOME:-$HOME/.cache}/tshark-completion` and in memory for the current shell. The disk cache rebuilds when the TShark version changes.

If you add a dissector without changing the TShark version, rebuild the cache in a Zsh session after using the completion at least once:

```zsh
tshark-completion-refresh
```

This project covers a useful subset of TShark options. It suggests field names by prefix, but does not parse complete display filter expressions or BPF capture filter syntax. See [features and limitations](docs/architecture.md) and the [technical guide](docs/technical-guide.md) for details.

## Uninstall

Remove `${ZDOTDIR:-$HOME}/.zsh/completions/_tshark` and the three-line block between `# >>> tshark-zsh-completion >>>` and `# <<< tshark-zsh-completion <<<` in `.zshrc`. If the installer added `autoload -Uz compinit` and `compinit`, remove those two lines only if no other completion uses them. Optionally remove `${XDG_CACHE_HOME:-$HOME/.cache}/tshark-completion`.

Licensed under the [MIT License](LICENSE).
