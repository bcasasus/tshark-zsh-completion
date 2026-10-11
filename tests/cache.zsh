#!/usr/bin/env zsh
emulate -L zsh
setopt nounset

repo=${0:A:h:h}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/cache"
cp "$repo/tests/fixtures/tshark" "$work/bin/tshark"
chmod +x "$work/bin/tshark"
export PATH="$work/bin:$PATH" XDG_CACHE_HOME="$work/cache"

_arguments() { : }
_describe() { reply=( "${(@P)2}" ) }
source "$repo/_tshark"

fail() { print -u2 -- "$1"; exit 1 }
_tshark_load_cache || fail 'cold cache generation failed'
[[ "${(j:,:)_tshark_protocol_cache}" == *'ip.'* ]] || fail 'missing protocol'
[[ "${(j:,:)_tshark_fields_cache}" == *'tcp.port:Port'* ]] || fail 'missing field'
local first=$(<"$_TSHARK_CURRENT_FILE")

MOCK_FIELDS=fail; export MOCK_FIELDS
if _tshark_build_cache; then fail 'failed command was accepted'; fi
[[ "$(<"$_TSHARK_CURRENT_FILE")" == "$first" ]] || fail 'failed command changed cache'
if tshark-completion-refresh >/dev/null 2>&1; then fail 'refresh accepted failure'; fi
[[ $_tshark_cache_loaded == 1 ]] || fail 'refresh discarded memory cache'

MOCK_FIELDS=empty; export MOCK_FIELDS
if _tshark_build_cache; then fail 'empty command was accepted'; fi
[[ "$(<"$_TSHARK_CURRENT_FILE")" == "$first" ]] || fail 'empty output changed cache'
unset MOCK_FIELDS

MOCK_VERSION=2.0; export MOCK_VERSION
_tshark_cache_loaded=0
_tshark_load_cache || fail 'version rebuild failed'
[[ "$(<"$(_tshark_active_generation)/version")" == 'TShark 2.0' ]] || fail 'stale version'

MOCK_MISSING=1; export MOCK_MISSING
_tshark_cache_loaded=0
local saved=$(<"$_TSHARK_CURRENT_FILE")
if _tshark_load_cache; then fail 'unavailable TShark was accepted'; fi
[[ "$(<"$_TSHARK_CURRENT_FILE")" == "$saved" ]] || fail 'unavailable TShark changed cache'
unset MOCK_MISSING
_tshark_load_cache || fail 'cache failed after TShark returned'
PREFIX='tcp.'
_tshark_fields
[[ "${(j:,:)reply}" == *'tcp.port:Port'* ]] || fail 'field completion failed'
PREFIX=''
_tshark_fields
[[ "${(j:,:)reply}" == *'ip.'* ]] || fail 'protocol completion failed'

_tshark_glossaries
[[ "${(j:,:)reply}" == *'fields:Field list'* ]] || fail '-G parsing failed'
_tshark_file_formats
[[ "${(j:,:)reply}" == *'pcapng:Wireshark Next Generation'* ]] || fail '-F parsing failed'
_tshark_output_formats
[[ "${(j:,:)reply}" == *'json:JSON values.'* ]] || fail '-T parsing failed'

_tshark_build_cache &
local pid1=$!
_tshark_build_cache &
local pid2=$!
wait "$pid1" "$pid2" || fail 'concurrent rebuild failed'
local final=$(_tshark_active_generation)
[[ -s "$final/fields" && -s "$final/protocols" ]] || fail 'concurrent cache invalid'
print 'cache and dynamic completion checks passed'
