#!/usr/bin/env bash

# Sync files from shared/ into $HOME, preserving their relative paths.

quiet=0
if [ "${1-}" = "--quiet" ]; then
  quiet=1
fi

if [ -n "${DOTS_ROOT-}" ] && [ -d "${DOTS_ROOT-}" ]; then
  repo_root="$DOTS_ROOT"
else
  if [ -n "${BASH_SOURCE-}" ]; then
    _src="${BASH_SOURCE[0]}"
  else
    _src="$0"
  fi
  _dir="$(cd -- "$(dirname -- "$_src")" && pwd -P)"
  repo_root="$(cd -- "$_dir/.." && pwd -P)"
fi

shared_root="$repo_root/shared"
[ -d "$shared_root" ] || exit 0

target_root="${HOME:-}"
[ -n "$target_root" ] || exit 0

while IFS= read -r -d '' src; do
  rel="${src#"$shared_root"/}"
  dest="$target_root/$rel"
  dest_dir="$(dirname -- "$dest")"

  if [ ! -d "$dest_dir" ]; then
    if ! mkdir -p "$dest_dir" 2>/dev/null; then
      [ "$quiet" -eq 1 ] || echo "shared-sync: cannot create $dest_dir" >&2
      continue
    fi
  fi

  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    continue
  fi

  if cp -p "$src" "$dest" 2>/dev/null; then
    [ "$quiet" -eq 1 ] || echo "shared-sync: $rel -> $dest" >&2
  else
    [ "$quiet" -eq 1 ] || echo "shared-sync: failed to copy $src -> $dest" >&2
  fi
done < <(find "$shared_root" -type f -print0 2>/dev/null)

exit 0
